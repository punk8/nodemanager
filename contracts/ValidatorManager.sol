pragma solidity ^0.5.11;
pragma experimental ABIEncoderV2;

contract ValidatorManager {
    // 配置信息
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
    // 事件
    event LogAddOperator(address operator);
    event LogRemoveOperator(address operator);
    event LogUpdateConfigByOperator(address operator, string pubkey, string network_addresses);

    function addOperator(address operator) onlyAdmin external {
        // [1] 验证存在与否
        require(operatorsExist[operator] == false);
        // [2] 验证操作频率是否符合
        require(block.number >= (modifys[operator] + modify_frequency), "modify fast");
        // [3]添加到白名单
        _addOperator(operator);
    }

    function _addOperator(address operator) internal {
        operatorsExist[operator] = true;
        emit LogAddOperator(operator);
    }

    function removeOperator(address operator) onlyAdmin external {
        // [1] 验证存在与否
        require(operatorsExist[operator] == true);
        // [2] 验证操作频率是否符合
        require(block.number >= (modifys[operator] + modify_frequency), "modify fast");
        // [3]添加到黑名单
        _removeOperator(operator);
    }

    function _removeOperator(address operator) internal {
        operatorsExist[operator] = false;
        emit LogRemoveOperator(operator);
    }

    function updateConfig(string pubkey, string network_address) onlyOperator external {
        _updateConfig(Config(pubkey,network_address),msg.sender);
    }

    function _updateConfig(Config config, address operator) internal {
        // [1] 版本号配置更新
        configTable[operator][block.number] = config;
        versions[operator].push(block.number);
        emit LogUpdateConfigByOperator(operator, config.pubkey, config.networkAddresses);
    }

    function getOperatorsForP2p() external view
    returns (address[] memory) {

    }

    function getAvailableConfigForP2p(address operator) external view
    returns (Config memory) {
        uint256[] version = versions[operator];
        if (version.length != 0) {
            return configTable[operator][version.length-1];
        } else {
            return Config("","");
        }
    }

    // 共识层面获取operator
    function getOperatorsForConsensus(uint256 sync_height, uint256 commit_height, uint256 current_height) external view
    returns (address[] memory) {


    }

    // 共识层面获取operator的config
    function getAvailableConfigForConsensus(address operator, uint256 current_height, uint256 commit_height) external view
    returns (Config memory){
        uint256 availableVersion = _getAvailableVersion(operator,current_height-commit_height);
        if(availableVersion != 0) {
            return configTable[operators[i]][availableVersion];
        } else {
            return Config("","");
        }
    }

    function _getAvailableVersion(address operator, uint256 target_height) internal {
        uint256[] storage version = versions[operator];
        uint256 length = version.length;
        // TODO(改为倒序便利)
        for(uint256 i = 0; i<length; i++) {
            if(version[i] > target_version) {
                // 节点的最低版本号大于给定版本号，说明该节点在当前版本号下还未生效则返回0
                if (i==0) {
                    return 0;
                }
                return version[i-1];
            }
        }
        return version[length-1];
    }
}
