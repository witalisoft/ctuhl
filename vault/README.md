# Preface

This tutorial assume that you are already basically familiar with bash and the involved tools, namely terraform, vault and ssh. 
To be able to follow all examples we have to build all prerequisites first, which can be simply done by calling

```
./do prepare
```

Also there are helper tasks to execute all the needed tooling and to start/stop needed containers, so we can fully focus on the functionality and do not have to fiddle around with tooling issues. If you get stuck you can call `./do clean` at any time to reset everything to its initial state. 


# The problem

Before we start lets have a look at a typical SSH setup you would encounter in the wild at any common cloud provider. Typically you will upload your SSH public key to your cloud provider of choice beafore starting a new VM in. On VM start your provider will then provision a  `~/.ssh/authorized_keys` file via [cloud-init](https://cloudinit.readthedocs.io/en/latest/) allowing you to login from your local machine with yout provided ssh-key when a new host is started. 

To make it easier to replicate this setup locally we will use docker containers as stand-in doubles for real cloud VMs. To mimic the on-boot behavior of cloud init the docker containers are configured to re-generate it's SSH host keys on start. 

So lets start a docker container that contains an plain SSH server with the follwing simple SSH daemon configuration

<!-- file:ssh-with-authorized-keys/sshd_config -->
{{< highlight go "" >}}
Port 22
UsePAM yes

HostKey /ssh/ssh_host_rsa_key

AuthorizedKeysFile %h/.ssh/authorized_keys
{{< / highlight >}}
<!-- /file:ssh-with-authorized-keys/sshd_config -->

you can start the container by running

```
./do start-ssh-with-authorized-keys
```

As during the docker build of this container we baked in the previously generated SSH key of Bob and added it to the `~/authorized_keys` of the `admin-ssh-user´, we can log into this container by


```
ssh -p 1022 -i ssh-keys/bob_id_rsa admin-ssh-user@localhost
```

The first thing we notice is that on first connect, we have to verify the identity of the SSH server which is typically done by verifying the cryptographic fingerprints

```
The authenticity of host '[localhost]:1022 ([::1]:1022)' can't be established.
ECDSA key fingerprint is SHA256:c99kZespMBlc4yBnz0owUXb85l/hmuqBrpIc4rY0qOU.
Are you sure you want to continue connecting (yes/no)? 
```

We can happily accept the connection (after of course manually verifying the identity), and go on with what we wanted to do via SSH.
Lets step for a smal bit and contemplate what just happened. We tried to establish a secure connection to a remote server. To establish that this is really the server we wanted to connect to in the frist place (and not some man-in-the-middle attack) we had to manually verify the servers identity. Imagine you would have to do this, every time you connect to a new website. This certainly is an approach that may work for a small numbers of machines but does definitly not scale very well with larger installs.

The even bigger problem starts when a new instance of a VM is started. As the identity of the SSH server is generated when the SSH server is configured and in a cloud environment this is done on every machine boot, the next time you start a new server a new identity is generated and thus the servers fingerprint changes.
We can emulate this by restarting the docker container

```
./do stop-ssh-with-authorized-keys
./do start-ssh-with-authorized-keys
```

and try to login again

```
ssh -p 1022 -i ssh-keys/bob_rsa admin-ssh-user@localhost
```

now we get an ugly warning, because we told our local SSH client to trust the server at `localhost:1022`  with the fingerprint `SHA256:c99kZespMBlc4yBnz0owUXb85l/hmuqBrpIc4rY0qOU` but the fingerprint changed to `SHA256:6amS+onNlSlFK/0cw6IvS+EJ4rqAzlc1YTZLGuZTr2Y`.


```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Someone could be eavesdropping on you right now (man-in-the-middle attack)!
It is also possible that a host key has just been changed.
The fingerprint for the ECDSA key sent by the remote host is
SHA256:6amS+onNlSlFK/0cw6IvS+EJ4rqAzlc1YTZLGuZTr2Y.
Please contact your system administrator.
Add correct host key in /home/pelle/.ssh/known_hosts to get rid of this message.
Offending ECDSA key in /home/pelle/.ssh/known_hosts:43
  remove with:
  ssh-keygen -f "/home/pelle/.ssh/known_hosts" -R "[localhost]:1022"
ECDSA host key for [localhost]:1022 has changed and you have requested strict checking.
Host key verification failed.
```

The next problem becomes obvious when we need to allow a new user to access the admin-ssh-user of our machine. Because the setup relies on the fact that the users public key is previously known to the machines, we would need to add the ssh public key of the new user to all machines `~/authorized_keys` files.
So in order to allow Alice to login as well via

```
ssh -p 1022 -i ssh-keys/alice_id_rsa admin-ssh-user@localhost
```

We would need to re-provision of all machines with the new SSH keys.

These two problems both boil down to a missing [trust anchor](https://en.wikipedia.org/wiki/Trust_anchor) for both sides of the SSH connection.

When we connect to an SSH server it would be nice if we could verify the servers identity was created by someone we trust. Vice versa if the SSH server would be able to verify that the SSH key was issued by someone he trusts we could easily add more users without needing to re-provision all servers.

This is in essence the same problem that web browsers have. Users can not manually verify the certificates of all sites they access (nor can they for SSH). Instead each browser has a list of certificate authorities (CA) it trusts. Websites offering SSL then present certificates issued and signed by those CAs (or its descendants) and the browser is able to verify a websites authenticity by verifying the whole [certificate chain](https://en.wikipedia.org/wiki/Chain_of_trust) up to its ultimate root which are the CAs that are stored in the browsers or operating system trust store.

We can leverage this mechanism for SSH connections as well, and establish trust to individual SSH servers by using CAs that act a trust anchor for all SSH connections. This article will explain how to do this, using the SSH CA functionality of HashiCorp`s vault.


# Introducing Vault

Beside its functionality as secret store vault has builtin capabilities to mange CAs for securing websites with X509 certificates. More interestingly those CA facilities can also be used to create and sign keys that are used to encrypt SSH sessions.

## Creating a trusted host identity

Lets first look at the traffic direction from the SSH client to the host.  

To mimic the way a browser verifies a hosts authenticity we would need the public key of a CA locally, and this CA has to sign the SSH servers host key. By signing the host key, the signer indicates to any third party that the signer trusts the signee. This enables any party who trusts the signer to extend her trust to the signee as well.


We are gonna use a vault server in development mode, so we don't have to fiddle around with establishing a secure relation between the different parties using vault tokens. It is thou important to note that the relation between vault and all entities using vault is now an important part of our trust chain. If this chain can't be trusted everything that is derived from it (like in the current example a signed host key) can't be trusted as well. For more information about vault tokens look [here](https://www.vaultproject.io/docs/concepts/tokens/).

First thing we have to do, is starting the vault server that will act as our CA and trust anchor

```
./do start-vault
```

Vault uses tokens for all authentication purposes. For this tutorial we use the static token `root-token` for all vault interactions. If you want to see vault in action, visit http://localhost:8200, and use this root token to log in.


Next step is to create a backend in vault that is able to act as a CA. In vault those backends are called secret engines, and multiple of the same type can be created for different purposes. To configure vault we are gonna use terraform

First create a secret engine that is able to handle [SSH secrets](https://www.vaultproject.io/docs/secrets/ssh/)

<!-- snippet:vault_mount_host_ssh -->
{{< highlight go "" >}}
resource "vault_mount" "host_ssh" {
  path        = "host-ssh"
  type        = "ssh"
  description = "host-ssh"
}
{{< / highlight >}}
<!-- /snippet:vault_mount_host_ssh -->

next step is to create a role, specifing the exact details of the CA and how the keys should be signed 

<!-- snippet:vault_ssh_secret_backend_role_host_ssh_role -->
{{< highlight go "" >}}
resource "vault_ssh_secret_backend_role" "host_ssh_role" {
    name                    = "host-ssh"
    backend                 = vault_mount.host-ssh.path
    key_type                = "ca"
    allow_host_certificates = true
    allow_user_certificates = false
}
{{< / highlight >}}
<!-- /snippet:vault_ssh_secret_backend_role_host_ssh_role -->

we can then apply the configuration by running terraform against the running vault instance

```
./do terraform-apply
```

If we now look at the crated SSH secret backend in the UI we notice that it seems to be missing an actual CA kepair which would be needed to actually sign other keys. Reason for this is we first have to generate a keypair (we could also import a key that was created outside of vault, but we go for the easy approach here)

<!-- snippet:create_signing_key -->
{{< highlight go "" >}}
  curl \
    --header "X-Vault-Token: root-token" \
    --request POST \
    --data '{"generate_signing_key": true}' \
    http://localhost:8200/v1/host-ssh/config/ca 
{{< / highlight >}}
<!-- /snippet:create_signing_key -->


Now we are ready to go, we have a fully loaded and configured CA to sign our SSH host keys. We use the containers run script `run.sh` to sign the new host key on each container start. First step is to sign the host key of our SSH server

<!-- snippet:sign_host_key -->
{{< highlight go "" >}}
curl --silent \
    --header "X-Vault-Token: root-token" \
    --request POST \
    --data "{ \"cert_type\": \"host\", \"public_key\": \"$(cat /ssh/ssh_host_rsa_key.pub)\" }" \
    http://vault:8200/v1/host-ssh/sign/host-ssh | jq -r .data.signed_key > /ssh/ssh_host_rsa_key_signed.pub
{{< / highlight >}}
<!-- /snippet:sign_host_key -->

We post the key to sign via curl to the vault api and requesting a signed host key by `"cert_type": "host"`. The important part of the response, namely the signed host key is extracted via `jq` and written to a file.
The next step is important, because SSH is very picky about file permissions (for a good reason), but does not always tell us when if fails because of too open permissions

<!-- snippet:sign_host_key_permissions -->
{{< highlight go "" >}}
chmod 0640 /ssh/ssh_host_rsa_key_signed.pub
{{< / highlight >}}
<!-- /snippet:sign_host_key_permissions -->

The last step is to make this signed host key known the the SSH server

<!-- file:ssh-with-signed-hostkey/sshd_config -->
{{< highlight go "" >}}
Port 22

HostKey /ssh/ssh_host_rsa_key
HostCertificate /ssh/ssh_host_rsa_key_signed.pub

UsePAM yes{{< / highlight >}}
<!-- /file:ssh-with-signed-hostkey/sshd_config -->

And we are good to go to start the improved SSH server

```
./do start-ssh-with-signed-hostkey
```

Now to be finally able to connect we have to make the CAs public key known to our local SSH client. Vault exposes them via http so we can simply download the public key from `http://localhost:8200/v1/host-ssh/public_key` and add it to SSHs known hosts file with the `@cert-authority` configuration (we are gonna use a seperate `known_hosts` file here, to avoid messing with your real `~/.ssh/known_hosts`)

<!-- snippet:create_known_hosts -->
{{< highlight go "" >}}
  echo "@cert-authority localhost $(curl --silent http://localhost:8200/v1/host-ssh/public_key)" > "known_hosts"
{{< / highlight >}}
<!-- /snippet:create_known_hosts -->

If we run SSH using Bobs key and our special `known_hosts` now

```
ssh -o UserKnownHostsFile=./known_hosts  -p 2022 -i ssh-keys/bob_id_rsa admin-ssh-user@localhost
```

It seamlessy connects to the server and the authenticity is ensured by a trusted CA.


TODO revocation of keys
TODO immutable reasoning for re-provisioning
TODO ssh keys need to be updated
TODO host identity needs be be injected or verified each time
TODO vault trust anchor
TODO Because not all docker containers can bind to the default SSH port (tcp/22) we will use different SSH ports for the different example containers.
