# frozen_string_literal: true

# Safe subprocess execution with timeout, avoiding capture3+Timeout race.
#
# Usage:
#   stdout, stderr, status = Subprocess.run(
#     command: ["python3", "/path/to/script.py"],
#     env: {"PYTHONIOENCODING" => "utf-8"},
#     stdin_data: json_payload,
#     timeout_seconds: 300
#   )
#
require "open3"
require "timeout"

module Subprocess
  class << self
    def run(command:, env: {}, stdin_data: nil, timeout_seconds: nil)
      raise ArgumentError, "command must be an Array" unless command.is_a?(Array)

      stdout_str = +""
      stderr_str = +""
      status = nil

      Open3.popen3(env, *command) do |stdin, stdout, stderr, wait_thr|
        pid = wait_thr.pid

        # write stdin if provided
        if stdin_data
          stdin.write(stdin_data)
        end
        stdin.close

        # readers
        out_reader = Thread.new { stdout_str = stdout.read.to_s }
        err_reader = Thread.new { stderr_str = stderr.read.to_s }

        begin
          if timeout_seconds
            Timeout.timeout(timeout_seconds) { wait_thr.join }
          else
            wait_thr.join
          end
          status = wait_thr.value
        rescue Timeout::Error
          terminate_process(pid)
          # Ensure pipes are drained to avoid broken pipe/race
          out_reader.join
          err_reader.join
          raise
        ensure
          # Ensure readers are finished before leaving
          out_reader.join unless out_reader.stop?
          err_reader.join unless err_reader.stop?
        end
      end

      [stdout_str, stderr_str, status]
    end

    private

    def terminate_process(pid)
      begin
        Process.kill("TERM", pid)
      rescue Errno::ESRCH
        return
      end

      # wait briefly, then KILL
      begin
        Timeout.timeout(2) do
          Process.wait(pid)
        end
      rescue Timeout::Error, Errno::ECHILD
        begin
          Process.kill("KILL", pid)
        rescue Errno::ESRCH
          # already gone
        end
      end
    end
  end
end
