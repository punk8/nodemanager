pragma solidity ^0.5.11;
pragma experimental ABIEncoderV2;

import "../contracts/NodesManager.sol";
import "truffle/Assert.sol";


contract TestNodesManager{

    // test add operator
    function testAddNode() public {

        NodesManager manager = new NodesManager(2);

        manager.addNode(0x0ff38e79a65db635275702Ac7b8b06ddEb4DB8e1);
        manager.addNode(0xb7adC0Ba1Ab109dD478E41C4e99921859D2C3e8C);
        manager.addNode(0x2027477341Bc48Be0a5c6d4a081A8f24d8208471);
        manager.addNode(0x11d53c437214255e18845d8581eA69CBCeA95D8D);
        manager.addNode(0xfE1B0D3dd3b82E9A1BD61D15cbc26a1aCC14DfE8);

        address[] memory operator = manager.getOperatorsForP2p();
        Assert.equal(operator.length, 5, "operator size");

        NodesManager.Config[] memory configs = manager.getAvailableNodesForP2p();
        Assert.equal(0, configs.length, "configs size");


    }

    // test update node
    function testUpdateInfo() public {

        NodesManager manager = new NodesManager(2);
        manager.addNode(manager.getAdmin());
        manager.updateNodeConfig("0ff38e79a65db635275702Ac7b8b06ddEb4DB8e1","localhost:7100");
        NodesManager.Config[] memory configs = manager.getAvailableNodesForP2p();

        Assert.equal(configs.length,1, "TestUpdate");
        Assert.equal("localhost:7100", configs[0].networkAddresses, "config network address");
        Assert.equal("0ff38e79a65db635275702Ac7b8b06ddEb4DB8e1", configs[0].pubkey, "config pubkey");

        manager.updateNodeConfig("fE1B0D3dd3b82E9A1BD61D15cbc26a1aCC14DfE8","localhost:7100;localhost:7200");
        configs = manager.getAvailableNodesForP2p();

        Assert.equal("localhost:7100;localhost:7200", configs[0].networkAddresses, "config network address");
        Assert.equal("fE1B0D3dd3b82E9A1BD61D15cbc26a1aCC14DfE8", configs[0].pubkey, "config pubkey");
    }

    // test remove node
    function testRemoveNode() public {

        NodesManager manager = new NodesManager(0);
        manager.addNode(manager.getAdmin());
        manager.updateNodeConfig("0ff38e79a65db635275702Ac7b8b06ddEb4DB8e1","localhost:7100");
        NodesManager.Config[] memory configs = manager.getAvailableNodesForP2p();

        Assert.equal(configs.length,1, "configs size");
        Assert.equal("localhost:7100", configs[0].networkAddresses, "config network address");
        Assert.equal("0ff38e79a65db635275702Ac7b8b06ddEb4DB8e1", configs[0].pubkey, "config pubkey");

        manager.removeNode(manager.getAdmin());
        configs = manager.getAvailableNodesForP2p();

        Assert.equal(0, configs.length, "configs size");

    }

    // test p2p and consensus
    function testConsensus() public {

        NodesManager manager = new NodesManager(0);
        manager.addNode(manager.getAdmin());
        manager.updateNodeConfig("0ff38e79a65db635275702Ac7b8b06ddEb4DB8e1","localhost:7100");

        NodesManager.Config[] memory configs = manager.getAvailableNodesForP2p();

        NodesManager.Config[] memory configsForConsensus = manager.getAvailableNodesForConsensus(0,0);

        Assert.equal(configs.length,1, "configs size");
        Assert.equal("localhost:7100", configs[0].networkAddresses, "network address");
        Assert.equal("0ff38e79a65db635275702Ac7b8b06ddEb4DB8e1", configs[0].pubkey, "pubkey");

        Assert.equal(configsForConsensus.length,1, "configsForConsensus size");
        Assert.equal("localhost:7100", configsForConsensus[0].networkAddresses, "TestRemoveOperator");
        Assert.equal("0ff38e79a65db635275702Ac7b8b06ddEb4DB8e1", configsForConsensus[0].pubkey, "TestRemoveOperator");


        configsForConsensus = manager.getAvailableNodesForConsensus(100,30);

        Assert.equal(configsForConsensus.length, 0, "configsForConsensus size");
    }

}
