const NodesManager = artifacts.require("./NodesManager");

module.exports = function (deployer) {
    deployer.deploy(NodesManager,2);
};
