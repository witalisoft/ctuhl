To be able to follow all examples you have to build all prerequisites first, which can simple be done by calling

```
./do build
```

assumptions
bash, vault, terraform, ssh

# The problem

Before we start lets have a look at a typical SSH setup you would encounter in the wild at any common cloud provider. Typically you will upload your SSH public key to your cloud provider of choice, who will then provision a  `~/.ssh/authorized_keys` file via [cloud-init](https://cloudinit.readthedocs.io/en/latest/) allowing you to login from your local machine when a new host is started. 

To make it easier to follow the instructions we will us docker locally as stand-in for real cloud VMs. As a rough analogy we can assume that the steps that happen during a docker build can be compared to the steps that happen when cloud-init is executed on a freshly started cloud VM.
Because not all docker containers can bind to the default SSH port (tcp/22) we will use different SSH ports for the different example containers.


So lets start a docker container that contains an plain SSH server with default configuration

```
docker-compose run -T -p 1022:22 ssh-authorized-keys
```

As during the docker build of this container we baked in the previously generated SSH key of Bob and added it to the `~/authorized_keys` of the `admin-ssh-user´, we can log into this container by


```
ssh -p 1022 -i ssh-keys/bob_id_rsa admin-ssh-user@localhost
```

The first thing we notice is that on first connect, we have to verify the identity of the SSH server which is typically done by verifying cryptographic fingerprints:

```
The authenticity of host '[localhost]:1022 ([::1]:1022)' can't be established.
ECDSA key fingerprint is SHA256:c99kZespMBlc4yBnz0owUXb85l/hmuqBrpIc4rY0qOU.
Are you sure you want to continue connecting (yes/no)? 
```

We can happily accept the connection (after of course manually verifying the identity), and go on with what we wanted to do via SSH.
The problem starts when a new instance of the VM is started. As the identity of the SSH server is generated when the SSH server is configured and in a cloud environment this is done on every machine boot, the next time you start a new server a new identity is generated and thus the servers fingerprint changes.
We can emulate this by rebuilding the docker image:

```
./do build
```

and then again start the SSH server and try to login

```
docker-compose run -T -p 1022:22 ssh-authorized-keys
ssh -p 1022 -i ssh-keys/bob_rsa admin-ssh-user@localhost
```

now when we try to connect, we get an ugly warning, because we told our local SSH to trust the server at `localhost:1022`  with the fingerprint `SHA256:c99kZespMBlc4yBnz0owUXb85l/hmuqBrpIc4rY0qOU` but the fingerprint changed to `SHA256:6amS+onNlSlFK/0cw6IvS+EJ4rqAzlc1YTZLGuZTr2Y`.


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

The next problem becomes obvious when we need to allow a new user to access the admin-ssh-user of our machines. Because the setup relies on the fact that the public key is previously known to the machines, we would need to add the ssh public key of the new user to all machines.
So in order to allow Alice to login as well via:

```
ssh -p 1022 -i ssh-keys/alice_id_rsa admin-ssh-user@localhost
```

We would need to re-provision of all machines with the new SSH keys.

These two problems both boil down to a missing [trust anchor](https://en.wikipedia.org/wiki/Trust_anchor) for both sides of the SSH connection.

When we connect to an SSH server it would be nice if we could verify the servers identity was created by someone we trust. Vice versa if the SSH server would be able to verify that the SSH key was issued by someone he trusts we could easily add more users without needing to re-provision all servers.

This is in essence the same problem that web browsers have. Users can not manually verify the certificates of all sites they access. Instead each browser has a list of certificate authorities (CA) it trusts. Websites offering SSL then present certificates issued and signed by those CAs (or its descendants) and the browser is able to verify a websites authenticity by verifying the whole [certificate chain](https://en.wikipedia.org/wiki/Chain_of_trust) up to its ultimate root which are the CAs that are stored in the browser or operating system.

We can leverage this mechanism for SSH connections as well, and establish trust to individual SSH servers by using CAs that act a trust anchor for all SSH connections. This article will explain how to do this, using the SSH CA functionality of HashiCorp`s secret store vault.


# Introducing Vault

Beside its functionality as secret store vault has builtin capabilities to mange CAs for securing websites with X509 certificates. More interestingly those CA facilities can also be used to create and sign keys that are used to encrypt SSH sessions.

## Creating a trusted host identity

Lets first look at the direction from the SSH client to the host.  

To mimic the way a browser verifies a hosts authenticity we would need the public key of a CA locally, and this CA has to sign the SSH servers identity. By signing the identity, the signer indicates to any third party that the signer trusts the signee. This enables someone who trusts the signer to extend her trust to the signee as well.


We are gonna use a vault server in development mode, so we don't have to fiddle with establishing a secure relation between the different parties using vault. It is thou important to note that the relation between vault and all entities using vault is now an important part of our trust chain. If this chain can't be trusted everything that is derived from it (like in the current example a signed host identity) can't be trusted as well. XXX explain vault tokens and link to more information? XXX

First we need to start the vault server, that will act as our trust anchor

```
./do start-vault
```

Vault uses tokens for all authentication purposes. For this tutorial we use the static token `root-token` for all vault interactions. If you want to see vault in action, visit http://localhost:8200, and use the root token to log in.


Next step is to create a backend in vault that is able to act as a CA. In vault those backends are called mounts, and multiple mounts can be crated of the same type for multiple purposes.

We will crate a CA for singing our SSH host identities:

```
resource "vault_mount" "host-ssh" {
  path        = "host-ssh"
  type        = "ssh"
  description = "host CA"
}
```

now we need to configure the mount as ca CA for singing host identities


```
resource "vault_ssh_secret_backend_role" "host-ssh_role" {
    name                    = "host-ssh"
    backend                 = vault_mount.host-ssh.path
    key_type                = "ca"
    allow_host_certificates = true
    allow_user_certificates = false
}
```

we can then apply the configuration by

```
./do terraform apply
```

XXX revocation of keys
XXX immutable reasoning for re-provisioning

```Creating config file /etc/ssh/sshd_config with new version
Creating SSH2 RSA key; this may take some time ...
2048 SHA256:1RqeGDZCVpk3Brybol8sp5tXHfszKKreVsLogXyw2xc root@2edf7b22b469 (RSA)
Creating SSH2 ECDSA key; this may take some time ...
256 SHA256:NFYnUPhtgjsN5t9oNHVznLYHfWFzkd6QMrHyRxlxrEk root@2edf7b22b469 (ECDSA)
Creating SSH2 ED25519 key; this may take some time ...
256 SHA256:y8VgcaWr1LzK2+AILxPkv2arMkVANnWjd86dDo9eUq4 root@2edf7b22b469 (ED25519)
```

ssh keys need to be updated
host identity needs be be injected or verified each time
vault trust anchor