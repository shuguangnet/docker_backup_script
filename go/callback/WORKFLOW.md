# GitHub Actions Workflow Documentation: `go-test.yml`

## Overview

This document provides a detailed explanation of the `go-test.yml` GitHub Actions workflow. Its primary purpose is to automate the testing of the Go-based callback handler application (`go/callback/`) in conjunction with the main `docker-backup.sh` script.

The workflow ensures that when the callback handler receives a correctly signed POST request (simulating an external system's callback), it can successfully execute the `docker-backup.sh` script with the provided arguments and that the backup process completes as expected.

## Workflow Trigger (`on`)

This workflow is triggered by:

- **`push`**: Any push to the `main` or `go-callback` branches.
- **`pull_request`**: Any pull request targeting the `main` or `go-callback` branches.

This ensures that changes to the Go application or the workflow itself are automatically tested.

## Job: `build-and-test` (`jobs.build-and-test`)

This is the sole job defined in the workflow. It runs on the `ubuntu-latest` runner environment.

### Steps

1.  **Checkout Code (`actions/checkout@v4`)**

    - Retrieves the repository code to the runner's workspace.

2.  **Set up Go (`actions/setup-go@v5`)**

    - Installs Go version 1.22 on the runner.

3.  **Cache Go Modules and Build (`actions/cache@v4`)**

    - Caches the Go module download directory (`~/go/pkg/mod`) and the Go build cache (`~/.cache/go-build`) to speed up subsequent workflow runs.

4.  **Install Dependencies (`go mod download`)**

    - Downloads the Go module dependencies specified in `go.mod`.

5.  **Build Application (`go build`)**

    - Compiles the Go application located in `go/callback/` into a single executable named `myapp` in the project root directory.

6.  **Create Test Files**

    - Dynamically generates two essential files for the test:
      - `backup.conf`: A configuration file for the Go application and `docker-backup.sh`.
        - `port=8080`: Configures the Go application to listen on port 8080.
        - `callback_secret=my-test-secret`: Sets the secret used to verify the signature of incoming callbacks.
        - `scriptpath=./docker-backup.sh`: Instructs the Go application to execute `./docker-backup.sh` when a valid callback is received.
      - This step no longer creates a mock `test-script.sh` as the workflow now uses the actual `docker-backup.sh`.

7.  **Run Integration Test**

    - This is the core testing logic:
      a. **Start Test Container**: Runs `docker run -d --name test-container nginx:alpine` to launch a simple Nginx container. This provides a real target for the `docker-backup.sh` script to back up.
      b. **Start Application**: Launches the compiled `myapp` in the background (`nohup ... &`), redirecting its logs to `app.log`.
      c. **Health Check**: Polls `http://localhost:8080` for up to 30 seconds to ensure the Go application has started and is ready to receive requests.
      d. **Prepare & Send Callback**:
      _ Constructs a SHA256 HMAC signature for the JSON payload `{"args":["test-container"]}` using the secret `my-test-secret`.
      _ Sends a `POST` request to `http://localhost:8080/backup` with:
      _ `Content-Type: application/json`
      _ `X-Signature: sha256=<calculated_signature>`
      _ Request Body: `{"args":["test-container"]}`
      _ This simulates an external system invoking the callback endpoint.
      e. **Verify Application Response**:
      _ Checks that the HTTP status code returned by the application is `200 OK`.
      _ Checks that the response body contains the string `"Backup initiated successfully"`. \* If either check fails, the workflow outputs the application logs (`app.log`) and the test container logs for debugging and then exits with an error.
      f. **Cleanup**: Attempts to terminate the `myapp` process and forcefully removes the `test-container`.

8.  **Output Application Logs (`if: always()`)**

    - Regardless of whether the previous steps succeeded or failed, this step prints the contents of `app.log`. This is invaluable for debugging any issues that occurred during the application's execution.

9.  **List Backup Artifacts (`if: always()`)**
    - Regardless of the test outcome, this step inspects the default backup output directory (`/tmp/docker-backups/`).
    - It lists the directory itself and, if any backup directories exist within it, lists the contents of each backup directory.
    - This verifies that `docker-backup.sh` was indeed executed by the Go application and produced the expected output structure.

## Interaction with `go/callback` Application

- The workflow builds and configures the application in `go/callback/`.
- It relies on the application's ability to:
  1.  Read its configuration from `backup.conf`.
  2.  Listen for `POST` requests on `/backup`.
  3.  Validate the `X-Signature` header against the request body using the `callback_secret`.
  4.  Parse the JSON body to extract the `args` array.
  5.  Execute the script specified by `scriptpath` (`./docker-backup.sh`) with the extracted `args` (e.g., `["test-container"]`).
  6.  Return a `200 OK` status with a success message upon initiating the script.

## Interaction with `docker-backup.sh`

- The workflow configures the `go/callback` application to execute `docker-backup.sh`.
- It provides a real Docker container (`test-container`) as an argument to `docker-backup.sh`.
- It verifies that `docker-backup.sh` creates its backup output in `/tmp/docker-backups/` by listing the directory contents.
