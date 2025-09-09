# Containerized API, Kafka Cluster, Lambda Consumer

Hello!

This is a containerized REST API &rarr; managed Kafka cluster &rarr; Lambda
consumer setup for AWS, provisioned with Terraform. I wrote it in
September,&nbsp;2025, in response to a take-home technical exercise for a
DevOps position with a medium-sized East Coast USA startup. It's complete
except for writing to Kafka (new for me, and a work in progress) and reading
from it (I've demonstrated reading streams of events in prior work).

Have fun experimenting with it, see if you can re-use parts of it in your own
projects, and feel free to send comments and questions. Thank you.

Jump to:
[Commentary](#commentary)
&bull;
[Licenses](#recommendations)
&bull;
[Licenses](#licenses)

## Getting Started

 1. Authenticate to a non-production AWS account, with a privileged role.
    **Switch to the `us-west-2` region**.

    > AWS service and feature availability varies by region, and changes over
    time. I tested in `us-west-2`&nbsp;. You can change the `aws_region_main`
    Terraform variable, perhaps in a local `terraform.tfvars` file.

 2. Create an EC2 instance. I recommend:
    - `arm64`
    - `t4g.micro`
    - Amazon Linux 2023
    - A 30&nbsp;GiB EBS volume, with default encryption (for hibernation
      support)
    - No key pair; connect with
      [Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html)
    - A custom security group with no ingress rules (yay for Session Manager!)
    - A `sched-stop` = `d=_ H:M=07:00` tag for automatic nightly shutdown (this
      example is for midnight Pacific Daylight Time) with
      [sqlxpert/lights-off-aws](https://github.com/sqlxpert/lights-off-aws#lights-off)

 3. During the instance creation workflow (Advanced details &rarr; IAM instance
    profile &rarr; Create new IAM profile) or afterward, give your EC2 instance
    a custom role. Within
    [terraform/iam.tf](/terraform/iam.tf?raw=true)
    in this repository, search for `"hello_api_maintain" =` to view a list of
    _AWS-managed_ policies covering the services and features used. Attach
    those policies to the instance role. It's not my trademark least-privilege,
    but it will do for a demonstration and it's better than `*:*`!

 4. Update packages (there shouldn't be any updates if you chose the latest
    Amazon Linux 2023 image), install Terraform, and install packages needed
    for building the Docker container.

    ```shell
    sudo dnf check-update
    sudo dnf --releasever=latest update

    sudo dnf install 'dnf-command(config-manager)'
    sudo dnf config-manager --add-repo 'https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo'
    sudo dnf install terraform-1.13.1-1

    sudo dnf install docker
    sudo dnf install python3.12
    ```

    You can make fun of me, but I use long option names wherever possible, so
    that other people don't have to look up unfamiliar single letters &mdash;
    assuming they _can_ find them. In
    [docs.docker.com/reference/cli/docker/buildx/build](https://docs.docker.com/reference/cli/docker/buildx/build/),
    for example, only 2 of 41 occurrences of `-t` are relevant.

 5. Uninstall the AWS CLI and replace it with the latest version.

    ```shell
    sudo dnf remove awscli
    
    cd /tmp
    curl 'https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip' --output 'awscliv2.zip'
    unzip awscliv2.zip
    sudo ./aws/install --update
    ```

 6. Clone this repository.

    ```shell
    cd ~
    git clone 'https://github.com/sqlxpert/z-container-api-kafka-aws-terraform.git'
    ```

 7. Initialize Terraform and create the AWS infrastructure. `terraform apply`
    outputs the plan and gives you a chance to approve, before anything is
    done. If you don't like the plan, don't type `yes`&nbsp;!

    > CloudPosse's otherwise excellent
    [dynamic-subnets](https://registry.terraform.io/modules/cloudposse/dynamic-subnets/aws/latest)
    module isn't dynamic enough to be integrated with AWS IP Address Manager
    (IPAM), which I use, so you have to allocate subnet IP addresses before
    continuing.

    ```shell
    cd ~/z-container-api-kafka-aws-terraform/terraform
    terraform init

    terraform apply -target='aws_vpc_ipam_pool_cidr_allocation.hello_api_vpc_private_subnets'
    terraform apply -target='aws_vpc_ipam_pool_cidr_allocation.hello_api_vpc_public_subnets'

    terraform apply
    ```

    **Copy the `hello_api_load_balander_domain_name` output value** to a note.
    This is the domain name of for your new API! You can't connect just yet, of
    course.

 8. Set environment variables needed for tagging and pushing the container
    image, then build the container.

    ```shell
    cd ~/z-container-api-kafka-aws-terraform/terraform

    AWS_ECR_REGISTRY_REGION=$(terraform output -raw 'hello_api_aws_ecr_registry_region')
    AWS_ECR_REGISTRY_URI=$(terraform output -raw 'hello_api_aws_ecr_registry_uri')
    AWS_ECR_REPOSITORY_URL=$(terraform output -raw 'hello_api_aws_ecr_repository_url')
    HELLO_API_AWS_ECR_IMAGE_TAG=$(terraform output -raw 'hello_api_aws_ecr_image_tag')

    cd ~/z-container-api-kafka-aws-terraform/python_docker

    sudo docker build --platform=linux/arm64 --tag "${AWS_ECR_REPOSITORY_URL}:${HELLO_API_AWS_ECR_IMAGE_TAG}" --progress=plain .

    aws ecr get-login-password --region "${AWS_ECR_REGISTRY_REGION}" | sudo docker login --username AWS --password-stdin "${AWS_ECR_REGISTRY_URI}"

    sudo docker push "${AWS_ECR_REPOSITORY_URL}:${HELLO_API_AWS_ECR_IMAGE_TAG}"
    ```

 9. In the Amazon Elastic Container Service section of the AWS Console, check
    the `hello_api` cluster. Eventually, you should see that 3 tasks are
    running.

    It will take a few minutes for ECS to notice, and then deploy, the
    container image. Relax, and let it happen. If you are impatient, or if
    there is problem, you can navigate to the `hello_api` service, open the
    orange "Update service" pop-up menu, and select "Force new deployment".

10. Using your Web browser, or `curl`&nbsp;, visit the following:

    - `http://DOMAIN/healtcheck`

    - `http://DOMAIN/hello`

    - `http://DOMAIN/current_time?name=test`

    where _DOMAIN_ is the output value that you noted at the end of
    Step&nbsp;7.

    Your Web browser should redirect you from `http:` to `https:` and (let's
    hope!) warn you about the untrusted, self-signed TLS certificate used for
    this demonstration. Proceed to view the responses from your new API...

    The health check should return nothing. `/hello` should return a fixed
    greeting, in a JSON object. `/current_time?name=SHORTNAME` should return a
    reflected greeting and a timestamp, again in a JSON object.

    The API will return error messages for unexpected inputs. To prevent
    command injection attacks, I have limited the length and character set for
    _SHORTNAME_.

    If your Web browser configuration does not allow accessing Web sites with
    untrusted certificates, change the `enable_https` Terraform variable,
    `terraform apply` twice (don't ask!) and `http:` links will work without
    redirection. (Once you have used `https:` with a particular site, your
    browser might no longer allow `http:` for that site. Use a separate Web
    browser if necessary.)

11. For more excitement, access the
    [`hello_api_ecs_task`](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups$3FlogGroupNameFilter$3Dhello_api_ecs)
    CloudWatch log group in the AWS Console. (`hello_api_ecs_cluster` is
    reserved for future use.)

    Periodic internal health checks, plus your occasional Web requests, should
    appear.

12. Delete this infrastructure as soon as you are done experimenting. I've
    chosen low-cost options but they are not free.

    `terraform apply -destroy` is a quick solution.

    Expect a slow deletion process for the VPC and for IPAM. You might prefer
    to interrupt Terraform, delete the `hello_api` VPC and the IPAM pool
    cascade manually in the AWS Console, then repeat `terraform apply
    -destroy`&nbsp;.

    Expect an error message about retiring KMS encryption key grants (harmless,
    in this case).

## Commentary

### Statement on AI, LLMs and Code Generation

This is my own work, produced _without_ the use of artificial intelligence /
large language model code generation. Code from other sources is acknowledged.

### Limitations

This is a comprehensive, working solution, though as a demonstration project,
it is not intended for production use.

Producing a working solution required significant free labor. To limit free
labor, I:

- **Omitted a local environment.** Local packaging and testing of Docker
  containers meant to be deployed in the cloud, and local execution of
  `terraform apply` for cloud resources, introduce variability and risk without
  much benefit. I created an EC2 instance in the AWS Console and used its EBS
  volume to store Terraform state during development.
  [AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html)
  would also work well for manual container generation tasks (but not for
  storing local Terraform state).
  [Shareable Lambda function test events](https://docs.aws.amazon.com/lambda/latest/dg/testing-functions.html#creating-shareable-events)
  offer a great way to bundle test events in IaC templates. Users can trigger
  realistic tests in a development AWS account, using either the AWS Console or
  the AWS&nbsp;CLI.

- **Omitted writing to Kafka.** The solution creates an MSK Serverless
  cluster, including appropriate networking. Because I am new to Kafka, MSK,
  and MSK Serverless, I ran out of time to debug and test Kafka authentication
  in Python. I show work-in-progress in a separate branch,
  [msk-in-progress](https://github.com/sqlxpert/z-container-api-kafka-aws-terraform/compare/b278fdd..msk-in-progress).
  I do look forward to learning more about Kafka and MSK, and will return to
  this when time permits.

- **Omitted the Kafka consumer Lambda function.** My prior open-source work
  demonstrates event-driven Lambda functions, including event source mappings,
  function scaling, batch handling, and modern, structured JSON logging. For
  an example with SQS as the event source, see
  [function setup](https://github.com/sqlxpert/lights-off-aws/blob/8e45026/cloudformation/lights_off_aws.yaml#L1728-L1767),
  [structured logging code](https://github.com/sqlxpert/lights-off-aws/blob/8e45026/cloudformation/lights_off_aws.yaml#L1832-L1847),
  and
  [event consumer code, resource permissions, and event source mapping](https://github.com/sqlxpert/lights-off-aws/blob/8e45026/cloudformation/lights_off_aws.yaml#L2470-L2538)
  in
  [github.com/sqlxpert/lights-off-aws](https://github.com/sqlxpert/lights-off-aws#lights-off)&nbsp;.
  Re-implementing the same pattern with a new event source would not say much.
  The intelligence lies in AWS's glue between MSK (or a different service) and
  Lambda; a simple consumer sees only batches of JSON-formatted events.

- **Omitted structured JSON logging for API access.** Unfortunately, it turns
  out that the OpenAPI Python module I chose early-on uses `uvicorn` workers,
  which
  [ignore custom log formats](https://stackoverflow.com/questions/62894952/fastapi-gunicorn-uvicorn-access-log-format-customization)
  passed in through `gunicorn`, and only
  [support a few fields](https://github.com/Kludex/uvicorn/blob/b7241e1/uvicorn/logging.py#L97-L114).
  My other work demonstrates structured JSON logging (link above), so I did not
  spend time writing code to override `uvicorn` (for log contents) or Python's
  logging system (for JSON formatting). In a slim container (part of the
  exercise!), I did not want the extra dependency of a third-party JSON logging
  module, either.

- **Omitted the architecture diagram.** Diagrams generated automatically from
  infrastructure-as-code templates might look pretty but their explanatory
  power is weak. The level of detail always seems too high for the audience.
  For example,
  [aws_iam_role_policy_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment)
  resources will be drawn with arrows between a role and multiple _AWS-managed_
  policies, when it would be sufficient to put the role and a list of the
  attached policies in a box, because AWS chooses descriptive policy names.
  Schooled by Dr. Edward Tufte's
  [_The Visual Display of Quantitative Information_](https://www.edwardtufte.com/book/the-visual-display-of-quantitative-information),
  I have produced compact, attractive, information-rich diagrams for my
  pre-existing open-source projects. They address multiple audiences and were
  easy to draw using Apple's free "Freeform" application. Click for examples:
  <br/>
  <br/>
  [<img src="https://github.com/sqlxpert/lights-off-aws/blob/60cdb5b/media/lights-off-aws-architecture-and-flow-thumb.png" alt="An Event Bridge Scheduler rule triggers the 'Find' Amazon Web Services Lambda function every 10 minutes. The function calls 'describe' methods, checks the resource records returned for tag keys such as 'sched-start', and uses regular expressions to check the tag values for day, hour, and minute terms. Current day and time elements are inserted into the regular expressions using 'strftime'. If there is a match, the function sends a message to a Simple Queue Service queue. The 'Do' function, triggered in response, checks whether the message has expired. If not, this function calls the method indicated by the message attributes, passing the message body for the parameters. If the request is successful or a known exception occurs and it is not okay to re-try, the function is done. If an unknown exception occurs, the message remains in the operation queue, becoming visibile again after 90 seconds. After 3 tries, a message goes from the operation queue to the error (dead letter) queue." height="144" />](https://github.com/sqlxpert/lights-off-aws/blob/60cdb5b/media/lights-off-aws-architecture-and-flow.png?raw=true "Architecture diagram and flowchart for Lights Off, AWS!")
  [<img src="https://github.com/sqlxpert/stay-stopped-aws-rds-aurora/blob/138a1b8/media/stay-stopped-aws-rds-aurora-flow-simple.png" alt="After waiting 9 minutes, call to stop the Relational Database Service or Aurora database. Case 1: If the stop request succeeds, retry. Case 2: If the Aurora cluster is in an invalid state, parse the error message to get the status. Case 3: If the RDS instance is in an invalid state, get the status by calling to describe the RDS instance. Exit if the database status from Case 2 or 3 is 'stopped' or another final status. Otherwise, retry every 9 minutes, for 24 hours." height="144" />](https://github.com/sqlxpert/stay-stopped-aws-rds-aurora/blob/138a1b8/media/stay-stopped-aws-rds-aurora-flow-simple.png?raw=true "Simplified flowchart for [Step-]Stay Stopped, RDS and Aurora!")
  [<img src="https://github.com/sqlxpert/stay-stopped-aws-rds-aurora/blob/138a1b8/media/stay-stopped-aws-rds-aurora-architecture-and-flow-thumb.png" alt="Relational Database Service Event Bridge events '0153' and '0154' (database started after exceeding 7-day maximum stop time) go to the main Simple Queue Service queue, where messages are initially delayed 9 minutes. The Amazon Web Services Lambda function stops the RDS instance or the Aurora cluster. If the database's status is invalid, the queue message becomes visible again in 9 minutes. A final status of 'stopping', 'deleting' or 'deleted' ends retries, as does an error status. After 160 tries (24 hours), the message goes to the error (dead letter) SQS queue." height="144" />](https://github.com/sqlxpert/stay-stopped-aws-rds-aurora/blob/138a1b8/media/stay-stopped-aws-rds-aurora-architecture-and-flow.png?raw=true "Architecture diagram and flowchart for Stay Stopped, RDS and Aurora!")

- **Used AWS-managed Identity and Access Management (IAM) policies** rather than
  write my trademark custom least-privilege policies. My long-standing
  open-source projects model least-privilege IAM policies. See, for example,
  the
  [CloudFormation deployment role](https://github.com/sqlxpert/lights-off-aws/blob/fe1b565/cloudformation/lights_off_aws_prereq.yaml#L83-L267)
  and the
  [Lambda function roles](https://github.com/sqlxpert/lights-off-aws/blob/8e45026/cloudformation/lights_off_aws.yaml#L484-L741)
  in
  [github.com/sqlxpert/lights-off-aws](https://github.com/sqlxpert/lights-off-aws#lights-off)&nbsp;.

- **Did not implement encryption in all places, or encryption with
  customer-managed KMS keys.** My pre-existing projects model comprehensive
  encryption, including support for custom KMS keys, keys housed in a dedicated
  AWS account, and multi-region keys. See, for example,
  [`SqsKmsKey`](https://github.com/sqlxpert/step-stay-stopped-aws-rds-aurora/blob/2da11e1/step_stay_stopped_aws_rds_aurora.yaml#L110-L127)
  in
  [github.com/sqlxpert/step-stay-stopped-aws-rds-aurora](https://github.com/sqlxpert/step-stay-stopped-aws-rds-aurora#step-stay-stopped-rds-and-aurora)&nbsp;.

- **Kept parameters to a minimum** (Terraform variables and outputs, for the
  purpose of this exercise). My pre-existing projects model extensive
  parameterization for flexibility and template re-use, plus simple defaults,
  complete parameter descriptions, and grouping of essential and non-essential
  parameters. See, for example, CloudFormation
  [`Parameters`](https://github.com/sqlxpert/lights-off-aws/blob/8e45026/cloudformation/lights_off_aws.yaml#L9-L288)
  and
  [`Metadata`](https://github.com/sqlxpert/lights-off-aws/blob/8e45026/cloudformation/lights_off_aws.yaml#L290-L399)
  in
  [github.com/sqlxpert/lights-off-aws](https://github.com/sqlxpert/lights-off-aws#lights-off)&nbsp;.
  I have also modeled the more AWS-idiomatic and scalable approach of using
  Systems Manager Parameter Store and path hierarchies. See
  [`ClientSecGrpIdParam`](https://github.com/sqlxpert/10-minute-aws-client-vpn/blob/1eb9028/10-minute-aws-client-vpn.yaml#L348-L362)
  in
  [github.com/sqlxpert/10-minute-aws-client-vpn](https://github.com/sqlxpert/10-minute-aws-client-vpn#10-minute-aws-client-vpn)&nbsp;.

### Recommendations

My professional and ethical commitment is simple: Only as much technology as a
business...

- needs,
- can afford,
- understands (or can learn), and
- can maintain.

Having worked for startups since 2013, I always recommend _focusing_
engineering effort during a company's formative years. It is not possible to
do everything, let alone to be good at everything. Managed services,
serverless technologies, and low-code solutions free engineers to focus on a
startup's core product. My recommendations assume that a startup has chosen
AWS as its cloud provider. (Multi-cloud support is not the core business of
most startups.)

|For this feature|The exercise required|I recommend|Because|
|:---|:---|:---|:---|
|API internals|A Docker container|AWS&nbsp;Lambda functions|There is much less infrastructure to specify and maintain, with Lambda. Source code for Lamdba functions of reasonable length can be specified in-line, eliminating the need for a packaging pipeline.|
|Container orchestration|ECS&nbsp;Fargate|ECS&nbsp;Fargate|When containers are truly necessary, ECS requires much less effort than EKS, and Fargate, less than EC2.|
|API presentation|(No requirement)|API&nbsp;Gateway|API&nbsp;Gateway makes it easy to implement rate-limiting/throttling. The service integrates directly with other relevant AWS services, including CloudWatch for logging and monitoring, and Web Application Firewall (WAF) for protection from distributed denial of service (DDOS) attacks.|
|Data streaming|Apache&nbsp;Kafka, via MSK|AWS Kinesis|Like Kinesis, the MSK _Serverless_ variant places the focus on usage rather than on cluster specification and operation. Still, everything seems to take more effort in Kafka. The boundary between infrastructure and data is unclear. Are topics to be managed as infrastructure, or as application data? I find the _need_ for "[Automate topic provisioning and configuration using Terraform](https://aws.amazon.com/blogs/big-data/automate-topic-provisioning-and-configuration-using-terraform-with-amazon-msk/)" ridiculous.|
|Consumer|An AWS&nbsp;Lambda function|An AWS&nbsp;Lambda function|(As above)|
|Logging|CloudWatch Logs|CloudWatch Logs|CloudWatch Logs is integrated with most AWS services. It requires less software installation effort (agents are included in AWS images) and much less configuration effort than alternatives like DataDog. Caution: CloudWatch is particularly expensive, but other centralized logging and monitoring products also become expensive at scale.|
|Infrastructure as code|Terraform|CloudFormation|CloudFormation:<ul><li>doesn't require the installation and constant upgrading of extra software;</li><li>steers users to simple, AWS-idiomatic resource definitions;</li><li>is covered, at no extra charge, by the existing AWS Support contract; and</li><li>supports creating multiple stacks from the same template, thanks to automatic resource naming.</li></ul>Note, in [Getting Started](#getting-started), the difficulty of bootstrapping Terraform. In the short time frame of this project, I had to code my own VPC gateway and interface endpoints because CloudPosse's [vpc-endpoints](https://registry.terraform.io/modules/cloudposse/vpc/aws/latest/submodules/vpc-endpoints) sub-modle is incompatible with the current Terraform AWS provider. I also documented a case where I couldn't use a basic AWS IPAM feature because it's not yet supported by the provider. All of this adds up to wasted effort that doesn't justify whatever benefits people ascribe to Terraform.|
## Licenses

|Scope|Link|Included Copy|
|:---|:---|:---|
|Source code, and source code in documentation|[GNU General Public License (GPL) 3.0](http://www.gnu.org/licenses/gpl-3.0.html)|[LICENSE_CODE.md](/LICENSE_CODE.md)|
|Documentation, including this ReadMe file|[GNU Free Documentation License (FDL) 1.3](http://www.gnu.org/licenses/fdl-1.3.html)|[LICENSE_DOC.md](/LICENSE_DOC.md)|

Copyright Paul Marcelin

Contact: `marcelin` at `cmu.edu` (replace "at" with `@`)
