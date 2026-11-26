# Configuring OIDC for CI Runners

To prevent static access keys where possible, CI runners should be configured to use workload identity federation. For most of the workflows in this repository that access external systems such as AWS and Tailscale, OIDC is applicable and can be configured. Below are references and a summary to configuring identity federation for all the relevant external systems.

## Systems

### Tailscale

**Reference:** [Tailscale OIDC](https://tailscale.com/docs/integrations/github/github-action#add-the-tailscale-github-action-using-a-federated-oidc-identity)

#### Summary

- Access the Tailscale admin console and create a tag in the JSON editor which will be used for ephemeral CI nodes. Grant the CI runner access to control plane nodes.

```json
{
  "tagOwners": {
    "tag:ci": ["group:admin"]
  },
  "grants": [
    {
      "src": ["tag:ci"],
      "dst": ["tag:talos"],
      "ip": ["tcp:6443", "tcp:50000"]
    }
  ]
}
```

- Create an GitHub OIDC trust credential in the Tailscale admin console. Set _Issuer_ to GitHub, and fill in the subject. When filling in the subject, use the new format for GitHub OIDC subject formats: `repo:org@12345/repo@67890:ref:refs/heads/main`.

- Configure the CI runner with the Tailscale setup action and the client id and audience configured of the trust credential in your Tailscale admin console.

```yaml
name: authenticate CI runner to tailnet
uses: tailscale/github-action@064b10558093f38325e838ddea35486bdc6b1d5c # v4.4.0
with:
  oauth-client-id: ${{ secrets.TAILSCALE_OAUTH_CLIENT_ID }}
  audience: ${{ secrets.TAILSCALE_OAUTH_AUDIENCE }}
  tags: tag:ci
```

### AWS
