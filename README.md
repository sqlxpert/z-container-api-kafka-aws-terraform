# Containerized API, Kafka Cluster, Lambda Consumer

Hello!

This is a containerized REST API &rarr; managed Kafka cluster &rarr; Lambda
consumer system for AWS, provisioned with Terraform and CloudFormation. I wrote
it in September,&nbsp;2025, in response to a take-home technical exercise
(hence the `z-` prefix).

Freed from the yoke of an uninsightful specification written by a non-AWS-savvy
organization, I enhanced the project's cost profile and network security in
October,&nbsp;2025.

Have fun experimenting with it, see if you can re-use parts of it under license
in your own projects, and feel free to send comments and questions!

Jump to:
[Commentary](#commentary)
&bull;
[Recommendations](#recommendations)
&bull;
[Licenses](#licenses)

## Getting Started

<details>
  <summary>Why these instructions include long option names...</summary>

<br/>

Make fun of me all you want, but I write long option names so that other
people don't have to look up unfamiliar single-letter options &mdash; assuming
they can _find_ them!

Here's an example that shows why I go to the trouble, even at the expense of
being laughed at by macho Linux users. I started using UNICOS in 1991, so it's
not for lack of experience.

Search for the literal text `-t` in
[docs.docker.com/reference/cli/docker/buildx/build](https://docs.docker.com/reference/cli/docker/buildx/build/)&nbsp;,
using Command-F, Control-F, `/`&nbsp;, or `grep`&nbsp;. Only
2&nbsp;of&nbsp;41&nbsp;occurrences of `-t` are relevant!

Where available, full-text (that is, not strictly literal) search engines
can't make sense of a 1-letter search term and are also likely to ignore a
2-character term as a "stop-word" that's too short to search for.

</details>

 1. Authenticate to the AWS Console. Use a non-production AWS account and a
    privileged role.

 2. Choose between
    [AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html)
    or an EC2 instance for building the container image and running Terraform.

    - **CloudShell**<br/>_Easy_ &check;

      - Open an
        [AWS CloudShell](https://console.aws.amazon.com/cloudshell/home)
        terminal.

      - Prepare for a cross-platform container image build. CloudShell
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

      <details>
        <summary>EC instance instructions...</summary>

      <br/>

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
          shutdown (this example corresponds to midnight Pacific Daylight Time)
          with
          [sqlxpert/lights-off-aws](https://github.com/sqlxpert/lights-off-aws#quick-start)

      - During the instance creation workflow (Advanced details &rarr; IAM
        instance profile &rarr; Create new IAM profile) or afterward, give
        your EC2 instance a custom role. The policies must be sufficient for
        Terraform to list/describe, get tags for, create, tag, untag, update,
        and delete all the AWS resource types included in this project's `.tf`
        files.

      - Update packages (thanks to AWS's
        [deterministic upgrade philosophy](https://docs.aws.amazon.com/linux/al2023/ug/deterministic-upgrades.html),
        there shouldn't be any updates if you chose the latest Amazon Linux
        2023 image), install Docker, and start it.

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

      </details>

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

    You may wish to create the `terraform.tfvars` file to customize variables.

    ```shell
    touch ~/z-container-api-kafka-aws-terraform/terraform/terraform.tfvars

    ```

 5. In CloudShell (optional if you chose EC2), configure the
    [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3).

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

    <details>
      <summary>In case of an "already exists" error...</summary>

    <br/>

    - If you receive a "Registry with name `lambda-testevent-schemas` already
      exists" error, set
      `create_lambda_testevent_schema_registry = false`&nbsp;, then run
      `terraform apply` again.

    </details>

 7. Set environment variables needed for building, tagging and pushing up the
    container image, then build the image.

    ```shell
    AMAZON_LINUX_BASE_VERSION=$(terraform output -raw 'amazon_linux_base_version')
    AMAZON_LINUX_BASE_DIGEST=$(terraform output -raw 'amazon_linux_base_digest')
    AWS_ECR_REGISTRY_REGION=$(terraform output -raw 'hello_api_aws_ecr_registry_region')
    AWS_ECR_REGISTRY_URI=$(terraform output -raw 'hello_api_aws_ecr_registry_uri')
    AWS_ECR_REPOSITORY_URL=$(terraform output -raw 'hello_api_aws_ecr_repository_url')
    HELLO_API_AWS_ECR_IMAGE_TAG=$(terraform output -raw 'hello_api_aws_ecr_image_tag')

    HELLO_API_DOMAIN_NAME=$(terraform output -raw 'hello_api_load_balander_domain_name') # For later

    aws ecr get-login-password --region "${AWS_ECR_REGISTRY_REGION}" | sudo docker login --username 'AWS' --password-stdin "${AWS_ECR_REGISTRY_URI}"

    cd ../python_docker

    ```

    ```shell
    sudo docker buildx build --build-arg AMAZON_LINUX_BASE_VERSION="${AMAZON_LINUX_BASE_VERSION}" --build-arg AMAZON_LINUX_BASE_DIGEST="${AMAZON_LINUX_BASE_DIGEST}" --platform='linux/arm64' --tag "${AWS_ECR_REPOSITORY_URL}:${HELLO_API_AWS_ECR_IMAGE_TAG}" --output 'type=docker' .
    ```

    ```shell
    sudo docker push "${AWS_ECR_REPOSITORY_URL}:${HELLO_API_AWS_ECR_IMAGE_TAG}"
    ```

    <details>
      <summary>Updating the container image...</summary>

    <br/>

    - You can select a newer Amazon Linux release by setting the
      `amazon_linux_base_version` and `amazon_linux_base_digest` variables in
      Terraform, running `terraform apply`&nbsp;, and re-setting the
      environment variables as described above.

      Then, to update the image, execute `HELLO_API_AWS_ECR_IMAGE_TAG='1.0.1'`
      (choose an appropriate new version number, taking
      [semantic versioning](https://semver.org/#semantic-versioning-specification-semver)
      into account), re-build the image, push it to the repository, set
      `hello_api_aws_ecr_image_tag = "1.0.1"` (for example) in Terraform, and
      run `terraform apply` again.

    </details>

 8. If you wish to enable Kafka, set `enable_kafka = true`&nbsp; then run
    `terraform apply`&nbsp;. AWS MSK is expensive, so enable Kafka only after
    confirming that the rest of the system is working for you.

    - For additional cost savings while you are experimenting, you can set
      `create_vpc_endpoints_and_load_balancer = false` until you have
      completed Step&nbsp;7.

 9. In the Amazon Elastic Container Service section of the AWS Console, check
    the `hello_api` cluster. Eventually, you should see that 2&nbsp;tasks are
    running.

    <details>
      <summary>ECS deployment time and task count...</summary>

    <br/>

    - It will take a few minutes for ECS to notice, and then deploy, the
      container image. Relax, and let it happen. If you are impatient, or if
      there is a problem, you can navigate to the `hello_api` service, open the
      orange "Update service" pop-up menu, and select "Force new deployment".

    - You can reduce the `hello_api_aws_ecs_service_desired_count_tasks`
      variable in Terraform, to a minimum of 0&nbsp;tasks (to eliminate ECS
      Fargate compute costs while you are experimenting). To demonstrate
      redundancy in 3&nbsp;availability zones, increase the value to
      3&nbsp;tasks or more.

    </details>

10. Generate the URLs and then test your API.

    ```shell
    echo -e "curl --location --insecure 'http://${HELLO_API_DOMAIN_NAME}/"{'healthcheck','hello','current_time?name=Paul','current_time?name=;echo','error'}"'\n"
    ```

    Try the different URLs using your Web browser or
    `curl --location --insecure`
    (the options allow redirection and self-signed TLS certificates).

    |URL|Result Expected|
    |:---|:---|
    |`http://DOMAIN/healthcheck`|Empty response|
    |`http://DOMAIN/hello`|Fixed greeting, in a JSON object|
    |`http://DOMAIN/current_time?name=Paul`|Reflected greeting and timestamp, in a JSON object|
    |`http://DOMAIN/current_time?name=;echo`|HTTP `400` "bad request" error;<br/>Demonstrates protection from command injection|
    |`http://DOMAIN/error`|HTTP `404` "not found" error|

    Replace _DOMAIN_ with the value of the
    `hello_api_load_balander_domain_name` Terraform output.

    <details>
      <summary>About HTTPS redirection and certificates...</summary>

    <br/>

    Your Web browser should redirect you from `http:` to `https:` and (let's
    hope!) warn you about the untrusted, self-signed TLS certificate used in
    this system (which of course is not tied to a pre-determined domain name).
    Proceed to view the responses from your new API...

    If your Web browser configuration does not allow accessing Web sites with
    untrusted certificates, change the `enable_https` variable in Terraform,
    run `terraform apply` _twice_ (don't ask!), and `http:` links will work
    without redirection. After you have used `https:` with a particular site,
    your browser might no longer allow `http:` for that site. Try an alternate
    Web browser if necessary.

    </details>

11. Access the
    [`hello_api_ecs_task`](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups$3FlogGroupNameFilter$3Dhello_api_ecs_)
    CloudWatch log group in the AWS Console. (`hello_api_ecs_cluster` is
    reserved for future use.)

    Periodic internal health checks, plus your occasional Web requests, should
    appear.

    <details>
      <summary>API access log limitations...</summary>

    <br/>

    The Python
    [connexion](https://connexion.readthedocs.io/en/stable)
    module, which I chose because it serves an API from a precise
    [OpenAPI-format specification](https://learn.openapis.org/introduction.html#api-description-using-the-oas),
    uses
    [uvicorn](https://uvicorn.dev)
    workers. Unfortunately,
    [uvicorn has lousy log format customization support](https://github.com/Kludex/uvicorn/issues/527).

    </details>

12. If you set `enable_kafka` to `true` in Step&nbsp;8, access the
    [HelloApiKafkaConsumer](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups$3FlogGroupNameFilter$3DHelloApiKafkaConsumer-LambdaFnLogGrp-)
    CloudWatch log group.

    Any reflected greetings were sent by the API code to Kafka, then retrieved
    from Kafka by the
    [AWS MSK event source mapping](https://docs.aws.amazon.com/lambda/latest/dg/with-msk-configure.html#msk-esm-overview),
    which in turn triggered the consumer Lambda function. It decodes the
    messages from Kafka and logs them.

13. Set the `enable_kafka`&nbsp;,
    `hello_api_aws_ecs_service_desired_count_tasks` and
    `create_vpc_endpoints_and_load_balancer` variables to their
    cost-saving values if you'd like to continue experimenting. When you are
    done, delete all resources; even the minimum configuration carries a cost.

    ```shell
    cd ../terraform
    terraform state rm 'aws_schemas_registry.lambda_testevent'
    terraform apply -destroy
    ```

    <details>
      <summary>Deletion delays and errors...</summary>

    <br/>

    - Deleting a VPC Lambda function takes a long time because of the network
      association; expect 30&nbsp;minutes if `enable_kafka` was `true`&nbsp;.

    - Expect an error message about retiring KMS encryption key grants
      (harmless, in this case).

    - If you must interrupt and resume the `terraform apply -destroy` process,
      a bug in CloudPosse's `dynamic-subnets` module can cause a "value
      depends on resource attributes that cannot be determined until apply"
      error. For a work-around, edit the cached module file indicated in the
      error message. Comment out the indicated line and force
      `count = 0`&nbsp;. Be sure to revert this temporary patch later.

    </details>

## Commentary

### Statement on AI, LLMs and Code Generation

This is my own work, produced _without_ the use of artificial intelligence /
large language model code generation. Code from other sources is acknowledged.

### Design Decisions

This is a comprehensive, working system. I made some executive decisions:

- **AWS CloudShell or EC2**
  Local building and testing of container images meant to be deployed in the
  cloud, and local execution of `terraform apply`  to create cloud resources,
  introduce variability and security risk without much benefit. Instead, I use
  the same Linux distribution (Amazon Linux 2023) that I selected for my
  container image, either on an EC2 instance or in
  [AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html).

- **Lambda Test Event**
  [Shareable Lambda function test events](https://builder.aws.com/content/33YuiyDjF5jHyRUhjoma00QwwbM/cloudformation-and-terraform-for-realistic-shareable-aws-lambda-test-events)
  offer a great way to bundle test events in infrastructure-as-code templates.
  Users can trigger realistic tests in a development AWS account, using the AWS
  Console, the AWS&nbsp;CLI, or a test program. See the
  [Lambda test event source](https://github.com/sqlxpert/z-container-api-kafka-aws-terraform/blob/d98c1cc/cloudformation/kafka_consumer.yaml#L567-L598).

- **CloudFormation for the Kafka Consumer**
  I defined the Kafka consumer in CloudFormation, called from Terraform,
  because I had complete and thoroughly-tested CloudFormation templates for
  Lambda functions and their dependencies, from my other projects. I speak both
  Terraform and CloudFormation, and each approach to infrastructure-as-code has
  its advantages. Here, re-using CloudFormation code saved me time. It also
  happens to establish a clean, modular separation between the Kafka producer
  and the consumer. The consumer only needs to know the MSK cluster ARN, the
  topic, and private subnet IDs and a security group ID for the VPC Lambda
  function.

- **PrivateLink**
  NAT Gateway is a very expensive AWS service, and from a network security
  perspective, it's better to keep as much network traffic private as possible.
  Accordingly, I define VPC endpoints for all necessary AWS services and leave
  the NAT Gateway off by default. I go a bit beyond AWS's recommendations for
  the endpoint security groups, using strict reciprocal pairs to determine
  which resources can access which AWS service endpoints, instead of opening
  them to entire subnets, let alone to the entire VPC. I don't use endpoint
  IAM policies, but could add them for even finer-grained control.

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
|API internals|A Docker container|AWS&nbsp;Lambda functions|There is much less infrastructure to specify and maintain, with Lambda. Source code for Lambda functions of reasonable length can be specified in-line, eliminating the need for a packaging pipeline.|
|Container orchestration|ECS&nbsp;Fargate|ECS&nbsp;Fargate|When containers are truly necessary, ECS requires much less effort than EKS, and Fargate, less than EC2.|
|API presentation|(No requirement)|API&nbsp;Gateway|API&nbsp;Gateway makes it easy to implement rate-limiting/throttling. The service integrates directly with other relevant AWS services, including CloudWatch for logging and monitoring, and Web Application Firewall (WAF) for protection from distributed denial of service (DDOS) attacks.|
|Data streaming|Apache&nbsp;Kafka, via MSK|AWS Kinesis|Like Kinesis, the MSK _Serverless_ variant places the focus on usage rather than on cluster specification and operation. Still, everything requires extra effort in Kafka. The boundary between infrastructure and data is unclear. Are topics to be managed as infrastructure, as application data, or as both? I find the _need_ for "[Automate topic provisioning and configuration using Terraform](https://aws.amazon.com/blogs/big-data/automate-topic-provisioning-and-configuration-using-terraform-with-amazon-msk/)" ridiculous. Should we depend on a module published and maintained by one person, and how do we assure its security, today and in the future? Should Terraform have permission to authenticate to Kafka and manipulate data?<br/><br/>The [MSK authentication source code provided by AWS](https://github.com/aws/aws-msk-iam-sasl-signer-python/issues) has 11 active issues, some open for more than one year. The `kafka-python` [`KafkaProducer.send`](https://kafka-python.readthedocs.io/en/master/apidoc/KafkaProducer.html#kafka.KafkaProducer.send) documentation mentions the return type but does not describe the contents; you have to [read the `kafka-python` source code](https://github.com/dpkp/kafka-python/blob/9227674/kafka/producer/future.py#L31-L74) yourself for that. The software has inconsistencies, such as using milliseconds for `KafkaProducer(request_timeout_ms)` but seconds for `KafkaProducer.send().get(timeout)`&nbsp;. Kafka and its software ecosystem is a rabbit warren of unnecessary complexity. A startup would be fine with SQS, or Kinesis for very high data volumes and/or for replayable streams, unless Kafka compatibility were part of the core business.|
|Consumer|An AWS&nbsp;Lambda function|An AWS&nbsp;Lambda function|(As above)|
|Logging|CloudWatch Logs|CloudWatch Logs|CloudWatch Logs is integrated with most AWS services. It requires less software installation effort (agents are included in AWS images) and much less configuration effort than alternatives like DataDog. Caution: CloudWatch is particularly expensive, but other centralized logging and monitoring products also become expensive at scale.|
|Infrastructure as code (for _AWS_ resources)|Terraform|CloudFormation|CloudFormation:<ul><li>doesn't require the installation and constant upgrading of extra software;</li><li>steers users to simple, AWS-idiomatic resource definitions;</li><li>is covered, at no extra charge, by the existing AWS Support contract; and</li><li>supports creating multiple stacks from the same template, thanks to automatic resource naming.</li></ul>Note, in [Getting Started](#getting-started), the relative difficulty of bootstrapping Terraform. I could have furnished a turn-key CloudFormation template, but before you can use Terraform you have to have environment in which to run it, you have to install it, and you have to set up a backend to store state information. In the short time that this project was under development, I had to code my own VPC endpoints because CloudPosse's [vpc-endpoints](https://registry.terraform.io/modules/cloudposse/vpc/aws/latest/submodules/vpc-endpoints) sub-module was incompatible with the current Terraform AWS provider, and I couldn't downgrade _that_ and break everything else. I also documented a case where I couldn't use a basic AWS IPAM feature: [resource planning pools are not supported by the Terraform AWS provider](https://github.com/hashicorp/terraform-provider-aws/issues/34615).<br/><br/>On a daily basis, and at scale, these foibles accumulate; the effort wasted diminishes the benefits that people ascribed to Terraform. (My advice is specifically for managing _AWS_ resources. Use whatever IaC tool you like for non-AWS stuff, prioritizing the many, close relationships between components created with the AWS API, over the few, weak dependencies between AWS- and non-AWS components.)|

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
