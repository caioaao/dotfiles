{ pkgs, ... }:

let
  modelDir = "/var/lib/llama-cpp/models";
  modelFile = "DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf";
  modelPath = "${modelDir}/${modelFile}";
  modelUrl = "https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-32B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-32B-Q4_K_M.gguf";

  inferenceThreads = "30";
  contextSize = "4096";
  batchSize = "512";
in
{
  environment.systemPackages = with pkgs; [
    llama-cpp
    wget
  ];

  systemd.services.llama-cpp-model-download = {
    description = "Download LLM model for llama.cpp";
    wantedBy = [ "multi-user.target" ];
    before = [ "llama-cpp.service" ];
    unitConfig = {
      ConditionPathExists = "!${modelPath}";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${modelDir}";
      ExecStart = toString (pkgs.writeShellScript "download-model" ''
        ${pkgs.wget}/bin/wget \
          --continue \
          --progress=dot:giga \
          --output-document="${modelPath}.downloading" \
          "${modelUrl}"
        mv "${modelPath}.downloading" "${modelPath}"
      '');
      TimeoutStartSec = "infinity";
    };
  };

  services.llama-cpp = {
    enable = true;
    host = "0.0.0.0";
    port = 8080;
    model = modelPath;
    extraFlags = [
      "--threads"        inferenceThreads
      "--ctx-size"       contextSize
      "--batch-size"     batchSize
      "--temp"           "0.6"
      "--top-p"          "0.95"
      "--repeat-penalty" "1.0"
      "--parallel"       "2"
    ];
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 8080 ];

  boot.kernel.sysctl = {
    "vm.max_map_count" = 1048576;
  };
}
