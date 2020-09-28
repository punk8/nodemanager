pragma solidity ^0.5.11;
pragma experimental ABIEncoderV2;

contract ValidatorManager {


    struct Config {
        string pubkey;
        string networkAddresses;
    }

    // 配置表
    mapping(address=>mapping(uint256=>Config)) configTable;

    // 记录节点的所有版本号集合
    mapping(address=>uint256[]) versions;

    // 记录operator的公钥信息
    address[] operatorKeys;
    mapping(address=>bool) operatorsExist;

    // admin对每个operator的更新记录
    mapping(address=>uint256) modifys;

    modifier onlyAdmin{
        require(msg.sender == admin);
        _;
    }

    modifier onlyOperator {
        require(operatorsExist[msg.sender] == true);
        _;
    }



    function addOperator(address operator) onlyAdmin external {
        // [1] 验证存在与否
        require(operatorsExist[operator] == false);
        // [2] 验证操作频率是否符合
        require(block.number >= (modifys[operator] + modify_frequency), "modify fast");

        operatorsExist[operator] = true;


        // 添加到白名单

    }


    function removeOperator(address operator) onlyAdmin external {
        // [1] 验证存在与否
        require(operatorsExist[operator] == true);
        // [2] 验证操作频率是否符合
        require(block.number >= (modifys[operator] + modify_frequency), "modify fast");

        operatorsExist[operator] = false;

        // 添加到黑名单
    }


    function updateConfig(string pubkey, string network_address) onlyOperator external {

        do_update(Config(pubkey,network_address));

    }



    function getOperators(uint256 current_height) external view
    returns (address[] memory) {

    }

    function getAvailableConfig(address operator, uint256 current_height) external view
    returns (Config memory) {

    }

    // 共识层面获取operator
    function getOperators(uint256 sync_height, uint256 commit_height, uint256 current_height) external view
    returns (address[] memory) {


    }


    // 共识层面获取operator的config
    function getAvailableConfig(address operator, uint256 current_height) external view
    returns (Config memory){

    }
}
