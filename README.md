# Resolving Oracle Cloud "Out of Capacity" issue and getting free VPS with 4 ARM cores / 24GB of memory
## How to start
```
1. Edit key.pem
2. Edit variables.env
3. Edit docker-compose.yml # optional
4. Run docker-compose up -d
```
## Instructions for variables.env & key.pem
Very neat and useful configuration was recently [announced](https://blogs.oracle.com/cloud-infrastructure/post/moving-to-ampere-a1-compute-instances-on-oracle-cloud-infrastructure-oci) at Oracle Cloud Infrastructure (OCI) blog as a part of Always Free tier. Unfortunately, as of July 2021, it's very complicated to launch an instance due to the "Out of Capacity" error. Here we're solving that issue as Oracle constantly adds capacity from time to time.

> Each tenancy gets the first 3,000 OCPU hours and 18,000 GB hours per month for free to create Ampere A1 Compute instances using the VM.Standard.A1.Flex shape (equivalent to 4 OCPUs and 24 GB of memory).

- [Resolving Oracle Cloud "Out of Capacity" issue and getting free VPS with 4 ARM cores / 24GB of memory](#resolving-oracle-cloud-out-of-capacity-issue-and-getting-free-vps-with-4-arm-cores--24gb-of-memory)
  - [How to start](#how-to-start)
  - [Instructions for variables.env \& key.pem](#instructions-for-variablesenv--keypem)
  - [Generating API key](#generating-api-key)
  - [Configuration](#configuration)
    - [General](#general)
    - [Private key](#private-key)
    - [Instance parameters](#instance-parameters)
      - [Mandatory](#mandatory)
        - [OCI\_SUBNET\_ID and OCI\_IMAGE\_ID](#oci_subnet_id-and-oci_image_id)
        - [OCI\_SSH\_PUBLIC\_KEY (SSH access)](#oci_ssh_public_key-ssh-access)
      - [Optional](#optional)
  - [How it works](#how-it-works)
  - [Assigning public IP address](#assigning-public-ip-address)
  - [Troubleshooting](#troubleshooting)
    - [SSH key issues](#ssh-key-issues)

## Generating API key

After logging in to OCI Console, click profile icon and then "User Settings"

Go to Resources -> API keys, click "Add API Key" button

Make sure "Generate API Key Pair" button is selected, click "Download Private Key" and then "Add".

Copy content from generated private key and paste it to `key.pem`.
## Configuration

### General

Region, user, tenancy, fingerprint should be taken from textarea during API key generation step.
Adjust these values in `.env` file accordingly:
- `OCI_REGION`
- `OCI_USER_ID`
- `OCI_TENANCY_ID`
- `OCI_KEY_FINGERPRINT`

### Private key

`OCI_PRIVATE_KEY_FILENAME` is an absolute path (including directories) or direct public accessible URL to your *.pem private key file.

### Instance parameters

#### Mandatory

##### OCI_SUBNET_ID and OCI_IMAGE_ID

You must start instance creation process from the OCI Console in the browser (Menu -> Compute -> Instances -> Create Instance)

Change image and shape. 
For Always free AMD x64 - make sure that "Always Free Eligible" availabilityDomain label is there:

ARMs can be created anywhere within your home region.

Adjust Networking section, set "Do not assign a public IPv4 address" checkbox. If you don't have existing VNIC/subnet, please create VM.Standard.E2.1.Micro instance before doing everything.

"Add SSH keys" section does not matter for us right now. Before clicking "Create"…

…open browser's dev tools -> network tab. Click "Create" and wait a bit most probably you'll get "Out of capacity" error. Now find /instances API call (red one)…

Find `subnetId`, `imageId` and set `OCI_SUBNET_ID`, `OCI_IMAGE_ID`, respectively.

Note `availabilityDomain` for yourself, then read the corresponding comment in `variables.env` file regarding `OCI_AVAILABILITY_DOMAIN`.

##### OCI_SSH_PUBLIC_KEY (SSH access)

In order to have secure shell (SSH) access to the instance you need to have a keypair, besically 2 files:
- ~/.ssh/id_rsa 
- ~/.ssh/id_rsa.pub

Second one (public key) contents (string) should be provided to a command below. 
The are plenty of tutorials on how to generate them (if you don't have them yet), we won't cover this part here.

```bash
cat ~/.ssh/id_rsa.pub
```

Output should be similar to
```bash
ssh-rsa <content> <localhost>
```

Change `OCI_SSH_PUBLIC_KEY` inside double quotes - paste the contents above (or you won't be able to login into the newly created instance).
**NB!** No new lines allowed!

#### Optional

`OCI_OCPUS` and `OCI_MEMORY_IN_GBS` are set `4` and `24` by default. Of course, you can safely adjust them. 
Possible values are 1/6, 2/12, 3/18 and 4/24, respectively.
Please notice that "Oracle Linux Cloud Developer" image can be created with at least 8GB of RAM (`OCI_MEMORY_IN_GBS`).

If for some reason your home region is running out of Always free AMD x64 (1/8 OPCU + 1GB RAM), replace values below.
**NB!** Setting the `OCI_AVAILABILITY_DOMAIN` to `Always Free Eligible` is mandatory for non-ARM architecture!
```bash
OCI_SHAPE=VM.Standard.E2.1.Micro
OCI_OCPUS=1
OCI_MEMORY_IN_GBS=1
OCI_AVAILABILITY_DOMAIN=FeVO:EU-FRANKFURT-1-AD-2
```

If you don't have instances of selected shape at all, and need only one, leave the value of `OCI_MAX_INSTANCES=1`. 
When you managed to launch one and need more (or 2 from scratch), set to `OCI_MAX_INSTANCES=2`. 


I bet that the output (error) will be similar to the one in a browser a few minutes ago
```json
{
    "code": "InternalError",
    "message": "Out of host capacity."
}
```
or if you already have instances:
```json
{
    "code": "LimitExceeded",
    "message": "The following service limits were exceeded: standard-a1-memory-count, standard-a1-core-count. Request a service limit increase from the service limits page in the console. "
}
```

## How it works

Before the instance creation, script will: 
1. Call [ListAvailabilityDomains](https://docs.oracle.com/en-us/iaas/api/#/en/identity/20160918/AvailabilityDomain/ListAvailabilityDomains) OCI API method
2. Call [ListInstances](https://docs.oracle.com/en-us/iaas/api/#/en/iaas/20160918/Instance/ListInstances) OCI API method
and check whether there're already existing instances with the same `OCI_SHAPE`, 
as well as number of them `OCI_MAX_INSTANCES` (you can safely adjust the last one if you wanna e.g. two `VM.Standard.A1.Flex` with 2/12 - 2 OCPUs and 12GB RAM - each).

Script won't create new instance if current (actual) number return from the API exceeds the one from `OCI_MAX_INSTANCES` variable.

## Assigning public IP address

We are not doing this during the command run due to the default limitation (2 ephemeral addresses per compartment). That's how you can achieve this. When you'll succeed with creating an instance, open OCI Console, go to Instance Details -> Resources -> Attached VNICs by selecting it's name


Then Resources -> IPv4 Addresses -> Edit


Choose ephemeral and click "Update"


## Troubleshooting

### SSH key issues
- If you have new line(s) / line ending(s) in `OCI_SSH_PUBLIC_KEY` you will encounter:
```json
{
  "code": "InvalidParameter",
  "message": "Unable to parse message body"
}
```
- If public key is incorrect:
```json
{
    "code": "InvalidParameter",
    "message": "Invalid ssh public key; must be in base64 format"
}
```
Copy the proper contents of `~/.ssh/id_rsa.pub` again and make sure it's inside double quotes. 
Or re-generate pair of keys. Make sure you won't unintentionally overwrite your existing ones. 