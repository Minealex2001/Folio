#ifndef RUNNER_SMB_NETWORK_PLUGIN_H_
#define RUNNER_SMB_NETWORK_PLUGIN_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>

#include <memory>

/// MethodChannel `folio/smb_network` — WNetAddConnection2 para rutas UNC.
class SmbNetworkPlugin {
 public:
  explicit SmbNetworkPlugin(flutter::BinaryMessenger* messenger);
  ~SmbNetworkPlugin();

 private:
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};

#endif  // RUNNER_SMB_NETWORK_PLUGIN_H_
