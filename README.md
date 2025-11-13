# Containerized Python API, Kafka, AWS Lambda Consumer

Hello! This is a high-quality **containerized Python API &rarr; managed Kafka
cluster &rarr; AWS Lambda consumer function** reference architecture,
provisioned with Terraform. (CloudFormation is used indirectly, for a modular
Kafka consumer stack.) I hope you will be able to adapt it for your own
projects, under the terms of the license.

Jump to:
[Installation](#installation)
&bull;
[Recommendations](#recommendations)
&bull;
[Licenses](#licenses)

## Innovations and Best Practices

<details name="innovations" open="true">
  <summary>Low-cost</summary>

- Expensive AWS resources can be toggled off during development
- [Spot pricing reduces compute costs up to 70%](https://aws.amazon.com/fargate/pricing#Fargate_Spot_Pricing_for_Amazon_ECS)
  even without a long-term, always-on Savings Plan commitment
- ARM CPU architecture offers a
  [better&nbsp;price/performance&nbsp;ratio](https://aws.amazon.com/ec2/graviton)
  than Intel

</details>

<details name="innovations">
  <summary>Secure Docker container</summary>

- Amazon Linux starts with fewer vulnerabilities, is updated frequently by AWS
  staff, and uses
  [deterministic&nbsp;operating&nbsp;system&nbsp;package&nbsp;versions](https://docs.aws.amazon.com/linux/al2023/ug/deterministic-upgrades.html)
- [AWS&nbsp;CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html)
  or EC2 provides a controlled, auditable environment for building container
  images
- The API server process runs as a non-root user, reducing the impact if it is
  compromised

</details>

<details name="innovations">
  <summary>Secure private network</summary>

- Security group rules refer to other named security groups rather than ranges
  of numeric addresses; only known pairs of resources can communicate
- [PrivateLink endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/privatelink-access-aws-services.html)
  keep AWS service traffic on the private network
- Private resources have no public Internet access

</details>

<details name="innovations">
  <summary>Compatible with Continuous integration/continuous deployment (CI/CD)</summary>

- Getting container image build properties from Terraform&nbsp;variables allows
  separate version for development, testing and blue/green deployment
- [AWS&nbsp;IP&nbsp;Address&nbsp;Manager&nbsp;(IPAM)](https://docs.aws.amazon.com/vpc/latest/ipam/what-it-is-ipam.html)
  takes a single address range input and divides the space flexibly,
  accommodating multiple environments of different sizes
- An AWS Lambda function test event in the
  [central,&nbsp;shared&nbsp;registry](https://builder.aws.com/content/33YuiyDjF5jHyRUhjoma00QwwbM/cloudformation-and-terraform-for-realistic-shareable-aws-lambda-test-events)
  allow for realistic central testing
- Amazon Linux on EC2 provides a consistent, central build platform

</details>

<details name="innovations">
  <summary>Small Docker container image</summary>

- [Docker&nbsp;cache&nbsp;mounts](https://docs.docker.com/build/cache/optimize/#use-cache-mounts)
  prevent image bloat _and_ avoid slow re-downloading on re-build (other people
  needlessly disable or empty operating system package and Python module
  caches)
- Temporary software is installed, used and removed in the same step,
  minimizing the number of layers while avoiding
  [multi&#8209;stage&nbsp;build](https://docs.docker.com/build/building/multi-stage#use-multi-stage-builds)
  complexity
- Temporary Python modules are uninstalled, just like temporary operating
  system packages (other people leave `pip`&nbsp;, which will never be used
  again!)

</details>

<details name="innovations">
  <summary>Low-code</summary>

- API methods, parameters and input validation rules are defined declaratively,
  in a standard
  [OpenAPI specification](https://learn.openapis.org/introduction.html#api-description-using-the-oas);
  API code need only process requests

- A managed container service (ECS) and a serverless computing option (Fargate)
  reduce infrastructure-as-code lines and eliminate scripts

- The
  [AWS&nbsp;event&nbsp;source&nbsp;mapping](https://docs.aws.amazon.com/lambda/latest/dg/with-msk-configure.html#msk-esm-overview)
  interacts with Kafka, so that the consumer Lambda function need only process
  JSON input (I re-used a simple _SQS_ consumer CloudFormation template from my
  other projects!)

</details>

Jump to:
[Recommendations](#recommendations)
&bull;
[Licenses](#licenses)

## Installation

 1. Choose between
    [AWS CloudShell](https://docs.aws.amazon.com/cloudshell/latest/userguide/welcome.html)
    or an EC2 instance for building the Docker image and running Terraform.

    - **CloudShell**<br/>_Easy_ &check;

      - Authenticate to the AWS Console. Use a non-production AWS account and
        a privileged role.

      - Open an
        [AWS CloudShell](https://console.aws.amazon.com/cloudshell/home)
        terminal.

      - Prepare for a cross-platform container image build. CloudShell seems to
        provide Intel CPUs. The following instructions are from
        "[Multi-platform builds](https://docs.docker.com/build/building/multi-platform/#prerequisites)"
        in the Docker Build manual.

        ```shell
        sudo docker buildx create --name 'container-builder' --driver 'docker-container' --bootstrap --use

        ```

        ```shell
        sudo docker run --privileged --rm 'tonistiigi/binfmt' --install all

        ```

      - Review the
        [Terraform S3 backend documentation](https://developer.hashicorp.com/terraform/language/backend/s3)
        and
        [create an S3 bucket](https://console.aws.amazon.com/s3/bucket/create?bucketType=general)
        to store Terraform state.

      - If at any time you find that your previous CloudShell session has
        expired, repeat any necessary software installation steps. Your home
        directory is preserved between sessions, subject to
        [CloudShell persistent storage limitations](https://docs.aws.amazon.com/cloudshell/latest/userguide/limits.html#persistent-storage-limitations).

    - **EC2 instance**

      <details>
        <summary>EC2 instructions...</summary>

      <br/>

      - Create and/or connect to an EC2 instance. I recommend:

        - `arm64`
        - `t4g.micro` &#9888; The ARM-based AWS Graviton `g` architecture
          avoids multi-platform build complexity.
        - Amazon Linux 2023
        - A 30&nbsp;GiB EBS volume, with default encryption (supports
          hibernation)
        - No key pair; connect through
          [Session Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-sessions-start.html)
        - A custom security group with no ingress rules (yay for Session
          Manager!)
        - A `sched-stop` = `d=_ H:M=07:00` tag for automatic nightly
          shutdown (this example corresponds to midnight Pacific Daylight Time)
          with
          [sqlxpert/lights-off-aws](https://github.com/sqlxpert/lights-off-aws#quick-start)

      - During the instance creation workflow (Advanced details &rarr; IAM
        instance profile &rarr; Create new IAM profile) or afterward, give
        your EC2 instance a custom role. Terraform must be able to
        list/describe, get tags for, create, tag, untag, update, and delete all
        of the AWS resource types included in this project's `.tf` files.

      - Update operating system packages (thanks to AWS's
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

 2. Install Terraform. I've standardized on
    [Terraform v1.10.0 (2024-11-27)](https://github.com/hashicorp/terraform/releases/tag/v1.10.0)
    as the minimum supported version for my open-source projects.

    ```shell
    sudo dnf --assumeyes install 'dnf-command(config-manager)'
    sudo dnf config-manager --add-repo 'https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo'
    # sudo dnf --assumeyes install terraform-1.10.0-1
    sudo dnf --assumeyes install terraform

    ```

 3. Clone this repository and create `terraform.tfvars` to customize variables.

    ```shell
    git clone 'https://github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws.git' ~/docker-python-openapi-kafka
    cd ~/docker-python-openapi-kafka/terraform
    touch terraform.tfvars

    ```

    <details>
      <summary>Generate a terraform.tfvars skeleton...</summary>

    <br/>

    ```shell
    # Requires an up-to-date GNU sed (not the MacOS default!)
    sed --regexp-extended --silent  \
        --expression='s/^variable "(.+)" \{$/\n\n# \1 =/p' \
        --expression='s/^  description = "(.+)"$/#\n# \1/p' \
        --expression='s/^  default = (.+)$/#\n# Default: \1/p' variables.tf

    ```

    </details>

    _Optional:_ To save money while building the Docker container image, set
    `hello_api_aws_ecs_service_desired_count_tasks = 0` and
    `create_vpc = false`&nbsp;.

 4. In CloudShell (optional if you chose EC2), create an override file to
    configure your Terraform S3 backend.

    ```shell
    cat > terraform_override.tf << 'EOF'
    terraform {
      backend "s3" {
        insecure = false

        region = "RegionCodeForYourS3Bucket"
        bucket = "NameOfYourS3Bucket"
        key    = "DesiredTerraformStateFileName"

        use_lockfile = true # No more DynamoDB; now S3-native!
      }
    }
    EOF

    ```

 5. Initialize Terraform and create the AWS infrastructure. There's no need for
    a separate `terraform plan` step. `terraform apply` outputs the plan and
    gives you a chance to approve before anything is done. If you don't like
    the plan, don't type `yes`&nbsp;!

    ```shell
    terraform init

    ```

    ```shell
    terraform apply -target='aws_vpc_ipam_pool_cidr_allocation.hello_vpc_subnets'

    ```

    <details>
      <summary>About this two-stage process...</summary>

    <br/>

    CloudPosse's otherwise excellent
    [dynamic-subnets](https://registry.terraform.io/modules/cloudposse/dynamic-subnets/aws/latest)
    module isn't dynamic enough to co-operate with
    [AWS&nbsp;IP&nbsp;Address&nbsp;Manager&nbsp;(IPAM)](https://docs.aws.amazon.com/vpc/latest/ipam/what-it-is-ipam.html),
    so you have to let IPAM finalize subnet IP address range allocations
    beforehand.

    </details>

    ```shell
    terraform apply

    ```

    <details>
      <summary>In case of "already exists" errors...</summary>

    <br/>

    - If you receive a "**RepositoryAlreadyExistsException**: The repository
      with name 'hello_api' already exists", set
      `create_aws_ecr_repository = false`&nbsp;.

    - If you receive a "**ConflictException**: Registry with name
      lambda-testevent-schemas already exists", set
      `create_lambda_testevent_schema_registry = false`&nbsp;.

    After changing the variable(s), run `terraform apply` again.

    </details>

 6. Set environment variables needed for building, tagging and pushing up the
    Docker container image, then build it.

    ```shell
    AMAZON_LINUX_BASE_VERSION=$(terraform output -raw 'amazon_linux_base_version')
    AMAZON_LINUX_BASE_DIGEST=$(terraform output -raw 'amazon_linux_base_digest')
    AWS_ECR_REGISTRY_REGION=$(terraform output -raw 'hello_api_aws_ecr_registry_region')
    AWS_ECR_REGISTRY_URI=$(terraform output -raw 'hello_api_aws_ecr_registry_uri')
    AWS_ECR_REPOSITORY_URL=$(terraform output -raw 'hello_api_aws_ecr_repository_url')
    HELLO_API_AWS_ECR_IMAGE_TAG=$(terraform output -raw 'hello_api_aws_ecr_image_tag')

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
      <summary>Scanning and updating the container image...</summary>

    <br/>

    In case you have _not_ configured ECR for automatic security scanning on
    image push, you may be able to initiate a free operating system-level
    vulnerability scan once per image per day. If you have opted-in to paid,
    enhanced scanning, you cannot initiate a scan manually. See
    [Scan images for software vulnerabilities in Amazon ECR](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-scanning.html)
    for all options.

    ```shell
    aws ecr start-image-scan --repository-name 'hello_api' --image-id "imageTag=${HELLO_API_AWS_ECR_IMAGE_TAG}"

    ```

    Carefully review findings from a manual or automatic vulnerability scan.

    ```shell
    aws ecr describe-image-scan-findings --repository-name 'hello_api' --image-id "imageTag=${HELLO_API_AWS_ECR_IMAGE_TAG}"

    ```

    You can resolve most or all operating system-level findings by specifying
    the version number and digest that correspond to the latest Amazon Linux
    2023 release. Its tag is `2023`&nbsp;, not the usual "latest". Resolving
    Python-level findings (from a paid, enhanced scan) might be as simple as
    re-building to pick up newer versions of secondary dependencies, or it
    might require updating primary module version numbers, in:

    - [`/python_docker/requirements.txt`](https://github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws/blob/main/python_docker/requirements.txt)
      _or_
    - [`/python_docker/Dockerfile`](https://github.com/sqlxpert/docker-python-openapi-kafka-terraform-cloudformation-aws/blob/main/python_docker/Dockerfile)&nbsp;.

    Note: For the Kafka consumer function,
    [AWS Lambda automatically applies security updates](https://docs.aws.amazon.com/lambda/latest/dg/runtimes-update.html)
    to the Lambda runtime.

    Set the `amazon_linux_base_version` and `amazon_linux_base_digest`
    variables in Terraform, run `terraform apply`&nbsp;, and re-set the
    environment variables.

    Then, to re-build the image, run `HELLO_API_AWS_ECR_IMAGE_TAG='1.0.1'`
    (choose an appropriate new version number, taking
    [semantic&nbsp;versioning](https://semver.org/#semantic-versioning-specification-semver)
    into account) in the shell and repeat the build and push commands.

    To deploy the new image version, set
    `hello_api_aws_ecr_image_tag = "1.0.1"` (for example) in Terraform and
    run `terraform apply` one more time.

    </details>

 7. _If_ you changed Terraform variables at the end of Step&nbsp;3, revert the
    changes and run _both_ `terraform apply` commands from Step&nbsp;5.

 8. In the Amazon Elastic Container Service section of the AWS Console, check
    the `hello_api` cluster. Eventually, you should see 2&nbsp;tasks running.

    - It will take a few minutes for ECS to notice, and then deploy, the
      container image. Relax, and let it happen. If you are impatient, or if
      there is a problem, you can navigate to the `hello_api` service, open the
      orange "Update service" pop-up menu, and select "Force new deployment".

 9. Generate the URLs and then test your API.

    ```shell
    cd ../terraform
    HELLO_API_DOMAIN_NAME=$(terraform output -raw 'hello_api_load_balander_domain_name')
    echo -e "curl --location --insecure 'http://${HELLO_API_DOMAIN_NAME}/"{'healthcheck','hello','current_time?name=Paul','current_time?name=;echo','error'}"'\n"

    ```

    Try the different URLs using your Web browser or
    `curl --location --insecure`
    (these options allow redirection and self-signed TLS certificates).

    |Method, parameters|Result expected|
    |:---|:---|
    |`/healthcheck`|Empty response|
    |`/hello`|Fixed greeting, in a JSON object|
    |`/current_time?name=Paul`|Reflected greeting and timestamp, in a JSON object|
    |`/current_time?name=;echo`|HTTP `400` "bad request" error;<br/>Demonstrates protection from command injection|
    |`/error`|HTTP `404` "not found" error|

    <details>
      <summary>About redirection to HTTPS, and certificates...</summary>

    <br/>

    Your Web browser should redirect you from `http:` to `https:` and (let's
    hope!) warn you about the untrusted, self-signed TLS certificate used in
    this system (which of course is not tied to a pre-determined domain name).
    Proceed to view the responses from your new API...

    If your browser configuration does not allow accessing Web sites with
    untrusted certificates, change the `enable_https` variable to `false` and
    run `terraform apply`&nbsp;. Now, `http:` links will work without
    redirection. After you have used `https:` with a particular domain, your
    browser might no longer allow `http:`&nbsp;. Try with another browser.

    </details>

10. Access the
    [`/hello/hello_api_web_log`](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups/log-group/$252Fhello$252Fhello_api_web_log)
    CloudWatch log group in the AWS Console.

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

11. If you wish to run commands remotely, or to open an interactive shell
    inside a `hello_api` container, use
    [ECS Exec](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html).

    <details>
      <summary>ECS Exec instructions...</summary>

    <br/>

    Change the `enable_ecs_exec` variable to `true`&nbsp;, run
    `terraform apply`&nbsp;, and replace the container(s) using "Force new
    deployment", as explained at the end of Step&nbsp;8.

    In the Amazon Elastic Container Service section of the AWS Console, click
    `hello_api` to open the cluster's page. Open the "Tasks" tab and click an
    identifier in the "Task" column. Under "Containers", select the container,
    then click "Connect". Confirm the command that will be executed.

    You can also use the AWS command-line interface from your main CloudShell
    session (or, with sufficient permissions, from an EC2 instance if you chose
    to deploy from EC2).

    ```shell
    aws ecs list-tasks --cluster 'hello_api' --query 'taskArns' --output text
    read -p 'Task ID: ' HELLO_API_ECS_TASK_ID
    aws ecs execute-command --cluster 'hello_api' --task "${HELLO_API_ECS_TASK_ID}" --interactive --command '/bin/bash'
    ```

    Activities are logged in the
    [`/hello/hello_api_ecs_exec_log`](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups/log-group/$252Fhello$252Fhello_api_ecs_exec_log)
    CloudWatch log group.

    </details>

12. If you don't wish use Kafka, skip to Step&nbsp;14.

    If you wish to enable Kafka, set `enable_kafka = true`&nbsp; and run
    `terraform apply`&nbsp;. AWS MSK is expensive, so enable Kafka only after
    confirming that the rest of the system is working for you.

    <details>
      <summary>In case HelloApiKafkaConsumer CloudFormation stack creation fails...</summary>

    <br/>

    Creation of the Kafka consumer might fail for various reasons. Once the
    `HelloApiKafkaConsumer` CloudFormation stack is in `ROLLBACK_COMPLETE`
    status, delete it, then run `terraform apply` again.

    </details>

13. Access the `/current_time?name=Paul` method several times (adjust the
    `name` parameter as you wish). The first use of this method prompts
    creation of the `events` Kafka topic. From now on, use of this method (not
    the other methods) will send a message to the `events` Kafka topic.

    The [AWS MSK event source mapping](https://docs.aws.amazon.com/lambda/latest/dg/with-msk-configure.html#msk-esm-overview)
    reads from the Kafka topic and triggers the consumer Lambda function, which
    logs decoded Kafka messages to the
    [HelloApiKafkaConsumer](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups$3FlogGroupNameFilter$3DHelloApiKafkaConsumer-LambdaFnLogGrp-)
    CloudWatch log group.

14. If you wish to continue experimenting, set the `enable_kafka`&nbsp;,
    `hello_api_aws_ecs_service_desired_count_tasks` and `create_vpc` variables
    to their cost-saving values and run `terraform apply`&nbsp;.

    When you are finished, delete all resources; the minimum configuration
    carries a cost.

    If you will be using the container image again soon, you can preserve the
    Elastic Container Registry image repository (at a cost) by removing it from
    Terraform state.

    ```shell
    cd ../terraform
    terraform state rm 'aws_schemas_registry.lambda_testevent'
    # terraform state rm 'aws_ecr_repository.hello' 'aws_ecr_lifecycle_policy.hello' 'data.aws_ecr_lifecycle_policy_document.hello'
    terraform apply -destroy
    ```

    <details>
      <summary>Deletion delays and errors...</summary>

    <br/>

    - Harmless "Invalid target address" errors will occur in some
      configurations.

    - A _newly-created_ ECR repository is deleted along with any images (unless
      you explicitly removed it from Terraform state), but if you _imported_
      your previously-created ECR repository and it contains images, you will
      receive a "**RepositoryNotEmptyException**". Either delete the images or
      remove the ECR repository from Terraform state. Run
      `terraform apply -destroy` again.

    - Deleting a VPC Lambda function takes a long time because of the network
      association; expect 30&nbsp;minutes if `enable_kafka` was `true`&nbsp;.

    - Expect an error message about retiring KMS encryption key grants
      (harmless, in this case).

    - If you cancel and re-run `terraform apply -destroy`&nbsp;, a bug in
      CloudPosse's `dynamic-subnets` module might cause a "value depends on
      resource attributes that cannot be determined until apply" error. For a
      work-around, edit the cached module file indicated in the error message.
      Comment out the indicated line and force `count = 0`&nbsp;. Be sure to
      revert this temporary patch later.

    </details>

## Comments

### Artificial Intelligence and Large Language Models (LLMs)

This is my own original work, produced _without_ the use of artificial
intelligence (AI) and large language model (LLM) code generation. Code from
other sources is acknowledged.

### Long Option Names

I write long option names in my instructions so that other people don't have to
look up unfamiliar single-letter options &mdash; assuming they can _find_ them!

Here's an example that shows why I go to the trouble, even at the expense of
being laughed at by macho Linux users. I started using
[UNICOS](https://en.wikipedia.org/wiki/UNICOS)
in 1991, so it's not for lack of experience.

> Search for the literal text `-t` in
[docs.docker.com/reference/cli/docker/buildx/build](https://docs.docker.com/reference/cli/docker/buildx/build/)&nbsp;,
using Command-F, Control-F, `/`&nbsp;, or `grep`&nbsp;. Only
2&nbsp;of&nbsp;41&nbsp;occurrences of `-t` are relevant!

Where available, full-text (that is, not strictly literal) search engines
can't make sense of a 1-letter search term and are also likely to ignore a
2-character term as a "stop-word" that's too short to search for.

### Recommendations

My professional and ethical commitment is simple: Only as much technology as a
business...

- needs,
- can afford,
- understands (or can learn), and
- can maintain.

Having worked for startups since 2013, I always recommend focusing software
engineering effort. It is not possible to do everything, let alone to be good
at everything. Managed services, serverless technology, and low-code
architecture free software engineers to _focus on the core product, that is, on
what the company actually sells_. Avoid complex infrastructure and tooling
unless it offers a unique, tangible, and substantial benefit. Simplicity pays!

Security is easier and cheaper to incorporate at the start than to graft on
after the architecture has been finalized, the infrastructure has been
templated and created, and the executable code has been written and deployed.

Specialized knowledge of the chosen cloud provider is indispensable. I call it
"idiomatic" knowledge, a good part of which is awareness of the _range of
options_ supported by your cloud provider. Building generically would mean
giving up some performance, some security, and some cloud cost savings.
Optimizing later is difficult. "Lean to steer the ship you're on."

## Licenses

|Scope|Link|Included Copy|
|:---|:---|:---|
|Source code, and source code in documentation|[GNU General Public License (GPL) 3.0](http://www.gnu.org/licenses/gpl-3.0.html)|[LICENSE_CODE.md](/LICENSE_CODE.md)|
|Documentation, including this ReadMe file|[GNU Free Documentation License (FDL) 1.3](http://www.gnu.org/licenses/fdl-1.3.html)|[LICENSE_DOC.md](/LICENSE_DOC.md)|

Copyright Paul Marcelin

Contact: `marcelin` at `cmu.edu` (replace "at" with `@`)
