package main

import (
	// "encoding/json"
	"encoding/json"
	"log"
	"os"
	"os/exec"
	"regexp"
	"sync"
)

type NodeSearchResults struct {
  Items []NodeData `json:"items"`
}

type NodeData struct {
	Metadata struct {
		Name string `json:"name"`
	} `json:"metadata"`
	Status struct {
		NodeInfo struct {
			KubeletVersion string `json:"kubeletVersion"`
			OsImage        string `json:"osImage"`
		} `json:"nodeInfo"`
	} `json:"status"`
}

func getNodesForLabel(label string) (nodes []NodeData)  {
	listNodesCommand := exec.Command(
		"kubectl", "get", "nodes",
		"-l", label,
		"-o", "json",
	)
	listNodesCommand.Stderr = os.Stderr
	data, err := listNodesCommand.Output()
	if err != nil {
		log.Fatal("Error getting nodes for label: ", label)
	}
	searchResults := &NodeSearchResults{}
	if err := json.Unmarshal(data, searchResults); err != nil {
		log.Fatal("Error parsing JSON results for label: ", err)
	}
	return searchResults.Items
}

func drainOutdatedNode(node NodeData) {
	drainNodeCommand := exec.Command(
		"kubectl", "drain", node.Metadata.Name,
		"--ignore-daemonsets",
		"--delete-emptydir-data",
		"--timeout=10m",
	)
	drainNodeCommand.Stdout = os.Stdout
	drainNodeCommand.Stderr = os.Stderr
	drainNodeCommand.Run()
}

func main() {
	kubeconfig := os.Getenv("KUBECONFIG")
	if kubeconfig == "" {
		log.Fatal("ConfigError: Kubeconfig is not set")
	}

	desiredTalosVersion := os.Getenv("TALOS_VERSION")
	desiredK8sVersion := os.Getenv("KUBE_VERSION")

	if desiredTalosVersion != "" && desiredK8sVersion != "" {
		log.Fatal("ConfigError: Either TALOS_VERSION or KUBE_VERSION must be set")
	} else if desiredTalosVersion == "" && desiredK8sVersion == "" {
		log.Fatal("ConfigError: Either TALOS_VERSION or KUBE_VERSION must be set")
	}

	nodeLabels := [3]string {
		"node.niovial.io/pool=system",
		"node.niovial.io/pool=general",
		"node.niovial.io/pool=database",
	}

	var wg sync.WaitGroup
	for _, label := range nodeLabels {
		wg.Go(func(){
			nodes := getNodesForLabel(label)
			osVersionRegex := regexp.MustCompile(`(v\d+.\d+.\d+)`)

			for _, node := range nodes {
				matches := osVersionRegex.FindStringSubmatch(node.Status.NodeInfo.OsImage)
				currentOs := matches[1]
				
				if (currentOs != desiredTalosVersion) && desiredTalosVersion != "" {
					drainOutdatedNode(node)
				} else if (node.Status.NodeInfo.KubeletVersion != desiredK8sVersion) && desiredK8sVersion != "" {
					drainOutdatedNode(node)
				}
				log.Print("Node ", node.Metadata.Name, " is up to date.")
			}
		})
	}
	wg.Wait()
}