# Containerized API, Kafka Cluster, Lambda Consumer

Hello!

This is a containerized REST API &rarr; managed Kafka cluster &rarr; Lambda
consumer setup for AWS, provisioned with Terraform. I wrote it in
September,&nbsp;2025, in response to a take-home technical exercise.

Have fun experimenting with it, see if you can re-use parts of it in your own
projects, and feel free to send comments and questions.

Freed from the yoke of a specification written by an uninsightful,
non-AWS-savvy employer, I'm going to add to this project as time permits.
I decided not to write the Lambda consumer initially, since I've
[demonstrated the Lambda consumer pattern in real-world software](#lambda-consumer-alternative).

Jump to:
[Commentary](#commentary)
&bull;
[Recommendations](#recommendations)
&bull;
[Licenses](#licenses)

## Getting Started

 1. Authenticate to the AWS Console. Use a non-production AWS account and a
    privileged role.

 2. Decide whether you'd like to use
    [AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html)
    or create an EC2 instance to build the Docker image and run Terraform.

    - **CloudShell**<br/>_Easy_ &check;

      - Open an
        [AWS CloudShell](https://console.aws.amazon.com/cloudshell/home)
        terminal.

      - Prepare for a cross-platform Docker image build. CloudShell
        seems to provide Intel CPUs, whereas I selected ARM to reduce
        ECS Fargate compute costs. These instructions are from
        [Multi-platform builds](https://docs.docker.com/build/building/multi-platform/#prerequisites)
        in the Docker Build manual.

        ```shell
        sudo docker buildx create --name container-builder --driver docker-container --bootstrap --use
        ```

        ```shell
        sudo docker run --privileged --rm tonistiigi/binfmt --install all
        ```

      - [Create an S3 bucket](https://console.aws.amazon.com/s3/bucket/create?bucketType=general)
        to store Terraform state.

      - If your previous session has expired, you can repeat setup commands as
        needed.

    - **EC2 instance**

      - Create an EC2 instance. I recommend:

        - `arm64`
        - `t4g.micro` &#9888; The ARM-based AWS Graviton `g` architecture
          avoids multi-platform build complexity; I selected ARM to
          reduce ECS Fargate compute costs.
        - Amazon Linux 2023
        - A 30&nbsp;GiB EBS volume, with default encryption (supports
          hibernation)
        - No key pair; connect with
          [Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html)
        - A custom security group with no ingress rules (yay for Session
          Manager!)
        - A `sched-stop` = `d=_ H:M=07:00` tag for automatic nightly
          shutdown (this example is for midnight Pacific Daylight Time)
          with
          [sqlxpert/lights-off-aws](https://github.com/sqlxpert/lights-off-aws#quick-start)

      - During the instance creation workflow (Advanced details &rarr; IAM
        instance profile &rarr; Create new IAM profile) or afterward, give
        your EC2 instance a custom role. The role's policies must be sufficient
        for Terraform to list/describe, get tags for, create, tag, untag,
        update, and delete all the AWS resource types included in the solution.

      - Update packages (thanks to AWS's
        [deterministic upgrade philosophy](https://docs.aws.amazon.com/linux/al2023/ug/deterministic-upgrades.html), there shouldn't be any updates if
        you chose the latest Amazon Linux 2023 image), install Docker,
        and start it.

        ```shell
        sudo dnf check-update
        ```

        ```shell
        sudo dnf --releasever=latest update
        ```

        ```shell
        sudo dnf install docker
        ```

        ```shell
        sudo systemctl start docker
        ```

 3. Install Terraform. I'm standardizing on
    [Terraform v1.10.0 (2024-11-27)](https://github.com/hashicorp/terraform/releases/tag/v1.10.0)
    as the minimum supported version for my open-source projects.

    ```shell
    sudo dnf --assumeyes install 'dnf-command(config-manager)'
    ```

    ```shell
    sudo dnf config-manager --add-repo 'https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo'
    sudo dnf --assumeyes install terraform-1.10.0-1
    ```

 4. Clone this repository.

    ```shell
    cd ~
    git clone 'https://github.com/sqlxpert/z-container-api-kafka-aws-terraform.git'
    cd z-container-api-kafka-aws-terraform/terraform
    ```

 5. In CloudShell only, configure the Terraform S3 backend.

    In `terraform.tf`&nbsp;, change the `terraform.backend` block to:

    ```terraform
      backend "s3" {
        insecure = false

        region = "RegionCodeForYourS3Bucket"
        bucket = "NameOfYourS3Bucket"
        key    = "DesiredTerraformStateFileName"

        use_lockfile = true # No more DynamoDB; now S3-native!
      }
    ```

 6. Initialize Terraform and create the AWS infrastructure. There's no need for
    a separate `terraform plan` step. `terraform apply` outputs the plan and
    gives you a chance to approve before anything is done. If you don't like
    the plan, don't type `yes`&nbsp;!

    > CloudPosse's otherwise excellent
    [dynamic-subnets](https://registry.terraform.io/modules/cloudposse/dynamic-subnets/aws/latest)
    module isn't dynamic enough to work with
    [AWS IP Address Manager
    (IPAM)](https://docs.aws.amazon.com/vpc/latest/ipam/what-it-is-ipam.html),
    so you have to allocate the subnet IP address ranges beforehand. I like
    IPAM because it does the work of dividing up one private IP address space.
    Specifying multiple, interdependent IP address ranges would produce a
    brittle configuration rather than a general-purpose, reusable
    infrastructure template.

    ```shell
    terraform init
    ```

    ```shell
    terraform apply -target='aws_vpc_ipam_pool_cidr_allocation.hello_api_vpc_private_subnets' -target='aws_vpc_ipam_pool_cidr_allocation.hello_api_vpc_public_subnets'
    ```

    ```shell
    terraform apply
    ```

 7. Set environment variables needed for tagging and pushing up the Docker
    image, then build the image.

    ```shell
    AWS_ECR_REGISTRY_REGION=$(terraform output -raw 'hello_api_aws_ecr_registry_region')
    AWS_ECR_REGISTRY_URI=$(terraform output -raw 'hello_api_aws_ecr_registry_uri')
    AWS_ECR_REPOSITORY_URL=$(terraform output -raw 'hello_api_aws_ecr_repository_url')
    HELLO_API_AWS_ECR_IMAGE_TAG=$(terraform output -raw 'hello_api_aws_ecr_image_tag')

    HELLO_API_DOMAIN_NAME=$(terraform output -raw 'hello_api_load_balander_domain_name') # For later

    cd ../python_docker
    ```

    ```shell
    sudo docker buildx build --platform='linux/arm64' --tag "${AWS_ECR_REPOSITORY_URL}:${HELLO_API_AWS_ECR_IMAGE_TAG}" --output 'type=docker' .
    ```

    ```shell
    aws ecr get-login-password --region "${AWS_ECR_REGISTRY_REGION}" | sudo docker login --username 'AWS' --password-stdin "${AWS_ECR_REGISTRY_URI}"
    ```

    ```shell
    sudo docker push "${AWS_ECR_REPOSITORY_URL}:${HELLO_API_AWS_ECR_IMAGE_TAG}"
    ```

 8. In the Amazon Elastic Container Service section of the AWS Console, check
    the `hello_api` cluster. Eventually, you should see that 3 tasks are
    running.

    It will take a few minutes for ECS to notice, and then deploy, the
    container image. Relax, and let it happen. If you are impatient, or if
    there is a problem, you can navigate to the `hello_api` service, open the
    orange "Update service" pop-up menu, and select "Force new deployment".

 9. Generate the URLs and then test your API.

    ```shell
    echo "'http://${HELLO_API_DOMAIN_NAME}/"{'healthcheck','hello','current_time?name=Paul','current_time?name=;echo','error'}"'"
    ```

    Using your Web browser, or `curl --location --insecure`&nbsp;, visit the
    different URLs.

    |URL|Result Expected|
    |:---|:---|
    |`http://DOMAIN/healthcheck`|Empty response|
    |`http://DOMAIN/hello`|Fixed greeting, in a JSON object|
    |`http://DOMAIN/current_time?name=Paul`|Reflected greeting and timestamp, in a JSON object|
    |`http://DOMAIN/current_time?name=;echo`|HTTP `400` "bad request" error;<br/>Demonstrates protection from command injection|
    |`http://DOMAIN/error`|HTTP `404` "not found" error|

    Replace _DOMAIN_ with the value of the `hello_api_load_balander_domain_name`
    Terraform output.

    Your Web browser should redirect you from `http:` to `https:` and (let's
    hope!) warn you about the untrusted, self-signed TLS certificate used for
    this demonstration. Proceed to view the responses from your new API...

    If your Web browser configuration does not allow accessing Web sites with
    untrusted certificates, change the `enable_https` Terraform variable,
    `terraform apply` twice (don't ask!), and `http:` links will work without
    redirection. (Once you have used `https:` with a particular site, your
    browser might no longer allow `http:` for that site. Use a separate Web
    browser if necessary.)

10. For more excitement, access the
    [`hello_api_ecs_task`](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups$3FlogGroupNameFilter$3Dhello_api_ecs)
    CloudWatch log group in the AWS Console. (`hello_api_ecs_cluster` is
    reserved for future use.)

    Periodic internal health checks, plus your occasional Web requests, should
    appear.

11. Delete the infrastructure as soon as you are done experimenting. I selected
    low-cost options but they are not free.

    ```shell
    cd ../terraform
    # terraform apply -destroy
    ```

    If any resource is slow to delete, you may wish to interrupt Terraform,
    delete the resource manually, and then re-run Terraform.

    Expect an error message about retiring KMS encryption key grants (harmless,
    in this case).

> Make fun of me all you want, but I write long option names (as in the
instructions above) so that other people don't have to look up unfamiliar
single-letter options &mdash; assuming they can _find_ them!
>
> Here's an example that shows why I go to the trouble, even at the expense of
being laughed at by macho Linux users. I started using UNICOS in 1991, so it's
not for lack of experience.
>
> Search for the literal text `-t` in
[docs.docker.com/reference/cli/docker/buildx/build](https://docs.docker.com/reference/cli/docker/buildx/build/)&nbsp;,
using Command-F, Control-F, `/`&nbsp;, or `grep`&nbsp;. Only
2&nbsp;of&nbsp;41&nbsp;occurrences of `-t` are relevant!
>
> Where available, full-text (that is, not strictly literal) search engines
can't make sense of a 1-letter search term and are also likely to ignore a
2-character term as a "stop-word" that's too short to search for.

## Commentary

### Statement on AI, LLMs and Code Generation

This is my own work, produced _without_ the use of artificial intelligence /
large language model code generation. Code from other sources is acknowledged.

### Limitations

This is a comprehensive, working solution, though as a demonstration project,
it is not intended for production use.

Producing a working solution required significant free labor. To limit free
labor, I:

- **Omitted a local environment.** Local building and testing of Docker
  containers meant to be deployed in the cloud, and local execution of
  `terraform apply` to create cloud resources, introduce variability and
  security risk without much benefit. Instead, I used the same Linux
  distribution (Amazon Linux 2023) that I'd selected for my Docker image,
  either on an EC2 instance or in
  [AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html).

  [Shareable Lambda function test events](https://builder.aws.com/content/33YuiyDjF5jHyRUhjoma00QwwbM/cloudformation-and-terraform-for-realistic-shareable-aws-lambda-test-events)
  offer a great way to bundle test events in IaC templates. Users can trigger
  realistic tests in a development AWS account, using either the AWS Console or
  the AWS&nbsp;CLI. See the
  [Lambda test event](https://github.com/sqlxpert/stay-stopped-aws-rds-aurora/blob/b9c2457/stay_stopped_aws_rds_aurora.yaml#L885-L970)
  that I have added to the CloudFormation template for my existing
  [github.com/sqlxpert/stay-stopped-aws-rds-aurora](https://github.com/sqlxpert/stay-stopped-aws-rds-aurora#stay-stopped-rds-and-aurora)
  project.

- <a name="lambda-consumer-alternative"></a>**Omitted the Kafka consumer Lambda
  function.** My prior open-source work demonstrates event-driven Lambda
  functions. For an example with SQS as the event source, see:

  - [least-privilege Lambda execution IAM role](https://github.com/sqlxpert/lights-off-aws/blob/8e45026/cloudformation/lights_off_aws.yaml#L572-L741)
  - [Lambda function setup](https://github.com/sqlxpert/lights-off-aws/blob/8e45026/cloudformation/lights_off_aws.yaml#L1728-L1767)
  - [event consumer Python code, resource permissions, and event source mapping](https://github.com/sqlxpert/lights-off-aws/blob/8e45026/cloudformation/lights_off_aws.yaml#L2470-L2538)

  in
  [github.com/sqlxpert/lights-off-aws](https://github.com/sqlxpert/lights-off-aws#lights-off)&nbsp;.

  Re-implementing the same pattern with a new event source would not say much.
  The intelligence lies in AWS's glue between MSK (or a different service) and
  Lambda; a simple consumer sees only batches of JSON-formatted events.

- **Omitted the architecture diagram.** Diagrams generated automatically from
  infrastructure-as-code templates might look pretty but their explanatory
  power is weak. The level of detail always seems too high or too low for the
  audience. Schooled by Dr. Edward Tufte's
  [_The Visual Display of Quantitative Information_](https://www.edwardtufte.com/book/the-visual-display-of-quantitative-information),
  I have produced compact, attractive, information-rich diagrams for my
  pre-existing open-source projects. They address multiple audiences and were
  easy to draw using Apple's free "Freeform" application. Click for examples:
  <br/>
  <br/>
  [<img src="https://github.com/sqlxpert/lights-off-aws/blob/60cdb5b/media/lights-off-aws-architecture-and-flow-thumb.png" alt="An Event Bridge Scheduler rule triggers the 'Find' Amazon Web Services Lambda function every 10 minutes. The function calls 'describe' methods, checks the resource records returned for tag keys such as 'sched-start', and uses regular expressions to check the tag values for day, hour, and minute terms. Current day and time elements are inserted into the regular expressions using 'strftime'. If there is a match, the function sends a message to a Simple Queue Service queue. The 'Do' function, triggered in response, checks whether the message has expired. If not, this function calls the method indicated by the message attributes, passing the message body for the parameters. If the request is successful or a known exception occurs and it is not okay to re-try, the function is done. If an unknown exception occurs, the message remains in the operation queue, becoming visibile again after 90 seconds. After 3 tries, a message goes from the operation queue to the error (dead letter) queue." height="144" />](https://github.com/sqlxpert/lights-off-aws/blob/60cdb5b/media/lights-off-aws-architecture-and-flow.png?raw=true "Architecture diagram and flowchart for Lights Off, AWS!")
  [<img src="https://github.com/sqlxpert/stay-stopped-aws-rds-aurora/blob/138a1b8/media/stay-stopped-aws-rds-aurora-flow-simple.png" alt="After waiting 9 minutes, call to stop the Relational Database Service or Aurora database. Case 1: If the stop request succeeds, retry. Case 2: If the Aurora cluster is in an invalid state, parse the error message to get the status. Case 3: If the RDS instance is in an invalid state, get the status by calling to describe the RDS instance. Exit if the database status from Case 2 or 3 is 'stopped' or another final status. Otherwise, retry every 9 minutes, for 24 hours." height="144" />](https://github.com/sqlxpert/stay-stopped-aws-rds-aurora/blob/138a1b8/media/stay-stopped-aws-rds-aurora-flow-simple.png?raw=true "Simplified flowchart for [Step-]Stay Stopped, RDS and Aurora!")
  [<img src="https://github.com/sqlxpert/stay-stopped-aws-rds-aurora/blob/138a1b8/media/stay-stopped-aws-rds-aurora-architecture-and-flow-thumb.png" alt="Relational Database Service Event Bridge events '0153' and '0154' (database started after exceeding 7-day maximum stop time) go to the main Simple Queue Service queue, where messages are initially delayed 9 minutes. The Amazon Web Services Lambda function stops the RDS instance or the Aurora cluster. If the database's status is invalid, the queue message becomes visible again in 9 minutes. A final status of 'stopping', 'deleting' or 'deleted' ends retries, as does an error status. After 160 tries (24 hours), the message goes to the error (dead letter) SQS queue." height="144" />](https://github.com/sqlxpert/stay-stopped-aws-rds-aurora/blob/138a1b8/media/stay-stopped-aws-rds-aurora-architecture-and-flow.png?raw=true "Architecture diagram and flowchart for Stay Stopped, RDS and Aurora!")

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
|Data streaming|Apache&nbsp;Kafka, via MSK|AWS Kinesis|Like Kinesis, the MSK _Serverless_ variant places the focus on usage rather than on cluster specification and operation. Still, everything requires extra effort in Kafka. The boundary between infrastructure and data is unclear. Are topics to be managed as infrastructure, as application data, or as both? I find the _need_ for "[Automate topic provisioning and configuration using Terraform](https://aws.amazon.com/blogs/big-data/automate-topic-provisioning-and-configuration-using-terraform-with-amazon-msk/)" ridiculous. Should we depend on a module published and maintained by one person, and how do we assure its security, today and in the future? Should Terraform have permission to authenticate to Kafka and manipulate data?<br/><br/>The [MSK authentication source code provided by AWS](https://github.com/aws/aws-msk-iam-sasl-signer-python/issues) has 11 active issues, some open for more than one year. The `kafka-python` [`KafkaProducer.send`](https://kafka-python.readthedocs.io/en/master/apidoc/KafkaProducer.html#kafka.KafkaProducer.send) documentation mentions the return type but does not describe the contents; you have to [read the `kafka-python` source code](https://github.com/dpkp/kafka-python/blob/9227674/kafka/producer/future.py#L31-L74) yourself for that. The software has inconsistencies, such as using milliseconds for `KafkaProducer(request_timeout_ms)` but seconds for `KafkaProducer.send().get(timeout)`&nbsp;. Kafka and its software ecosystem is a rabbit warren of unnecessary complexity. A startup would be fine with SQS, or Kinesis for very high data volumes and/or for replayable streams, unless Kafka compatibility were part of the core business.|
|Consumer|An AWS&nbsp;Lambda function|An AWS&nbsp;Lambda function|(As above)|
|Logging|CloudWatch Logs|CloudWatch Logs|CloudWatch Logs is integrated with most AWS services. It requires less software installation effort (agents are included in AWS images) and much less configuration effort than alternatives like DataDog. Caution: CloudWatch is particularly expensive, but other centralized logging and monitoring products also become expensive at scale.|
|Infrastructure as code (for _AWS_ resources)|Terraform|CloudFormation|CloudFormation:<ul><li>doesn't require the installation and constant upgrading of extra software;</li><li>steers users to simple, AWS-idiomatic resource definitions;</li><li>is covered, at no extra charge, by the existing AWS Support contract; and</li><li>supports creating multiple stacks from the same template, thanks to automatic resource naming.</li></ul>Note, in [Getting Started](#getting-started), the relative difficulty of bootstrapping Terraform. I could have furnished a turn-key CloudFormation template, but before you can use Terraform you must, at the very least, provision an IAM role manually. In the short time that this project was under development, I had to code my own VPC endpoints because CloudPosse's [vpc-endpoints](https://registry.terraform.io/modules/cloudposse/vpc/aws/latest/submodules/vpc-endpoints) sub-module is incompatible with the current Terraform AWS provider, and I couldn't downgrade _that_ and break everything else. I also documented a case where I couldn't use a basic AWS IPAM feature: [resource planning pools are not supported by the Terraform AWS provider](https://github.com/hashicorp/terraform-provider-aws/issues/34615).<br/><br/>On a daily basis, and at scale, these problems accumulate; the effort wasted diminishes the benefits that people ascribed to Terraform. (My advice is specifically for managing _AWS_ resources. Use whatever IaC tool you like for non-AWS stuff, prioritizing the many, close relationships between components created with the AWS API, over the few, weak dependencies between AWS- and non-AWS components.)|

In short, added complexity in any piece of software, any framework, any tool
had better come with a unique, tangible, and substantial benefit. Otherwise, a
resource-constrained startup is better off choosing the simpler alternative.

## Licenses

|Scope|Link|Included Copy|
|:---|:---|:---|
|Source code, and source code in documentation|[GNU General Public License (GPL) 3.0](http://www.gnu.org/licenses/gpl-3.0.html)|[LICENSE_CODE.md](/LICENSE_CODE.md)|
|Documentation, including this ReadMe file|[GNU Free Documentation License (FDL) 1.3](http://www.gnu.org/licenses/fdl-1.3.html)|[LICENSE_DOC.md](/LICENSE_DOC.md)|

Copyright Paul Marcelin

Contact: `marcelin` at `cmu.edu` (replace "at" with `@`)
