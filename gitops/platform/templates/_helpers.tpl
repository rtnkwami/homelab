{{- define "assumeRoleDocument" }}
{{- $oidcProvider := "s3.us-east-1.amazonaws.com/niovial-homelab-oidc" }}
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::{{ .Values.aws.accountId }}:oidc-provider/{{ $oidcProvider }}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "{{ $oidcProvider }}:sub": "system:serviceaccount:{{ .serviceAccountNamespace }}:{{ .serviceAccountName }}",
          "{{ $oidcProvider }}:aud": "sts.amazonaws.com"
        }
      }
    }
  ] 
}
{{- end -}}