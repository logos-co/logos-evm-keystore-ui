{
  description = "Logos evm_keystore_ui — the one surface that creates, imports, exports and deletes accounts.";

  inputs = {
    logos-module-builder.url = "github:logos-co/logos-module-builder";
    keystore_module = {
      url = "github:logos-co/logos-evm-keystore-module";
      inputs.logos-module-builder.follows = "logos-module-builder";
    };
    # The keys app is the manager's custodian: it decides open and unlock requests.
    signer_manager_module = {
      url = "github:logos-co/logos-signer-manager-module";
      inputs.logos-module-builder.follows = "logos-module-builder";
      inputs.keystore_module.follows = "keystore_module";
    };
  };

  # mkLogosQmlModule, NOT mkLogosModule: the generic builder compiles the plugin but never
  # assembles the QML, and the .lgx step then fails with "view file not found".
  outputs = inputs@{ logos-module-builder, ... }:
    logos-module-builder.lib.mkLogosQmlModule {
      src = ./.;
      configFile = ./metadata.json;
      flakeInputs = inputs;
    };
}
