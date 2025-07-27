package runner

import (
	"fmt"
	"os/exec"
)

// Run 执行指定路径的脚本，并传入参数
func Run(scriptPath string, args []string) ([]byte, error) {
	// Prepare command with script path and args
	cmdArgs := []string{scriptPath}
	cmdArgs = append(cmdArgs, args...)

	// Execute the backup script with args
	cmd := exec.Command("/bin/bash", cmdArgs...)
	cmd.Dir = "../.." // Set working directory to project root
	output, err := cmd.CombinedOutput()
	if err != nil {
		return output, fmt.Errorf("failed to execute backup script: %w\nOutput: %s", err, string(output))
	}

	return output, nil
}
