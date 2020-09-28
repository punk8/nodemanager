pragma solidity ^0.5.11;
pragma experimental ABIEncoderV2;

contract NodesManager {

    struct State {
        uint256 height;
        bool isSet;
    }

    // 黑白名单
    mapping(address=>State) whiteTable;
    mapping(address=>State) blackTable;

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

    // operator关联的pubkey
    mapping(address=>string) operator2pubkeys;

    address admin;

    // admin对每个operator的更新记录
    mapping(address=>uint256) modifys;

    // 全局状态的更新记录(包含admin与operator)
    uint256 lastChanged;

    // 允许admin对同一个operator的更新频率
    uint256 public modify_frequency;

    modifier onlyAdmin{
        require(msg.sender == admin);
        _;
    }

    constructor (uint256 _modify_frequency) public {
        admin = msg.sender;
        modify_frequency = _modify_frequency;
//        emit OPERATOR(admin);
        // _addNode(0xFE41F149BDa2c270E4b8F3F3Ba50f2c83325e51e);
    }


    // 测试用
    function getAdmin() external view
    returns (address){
        return admin;
    }


    function setModifyFrequency(uint256 _modify_frequency) external onlyAdmin{
        modify_frequency = _modify_frequency;
    }

    event BLOCKNUMBER(uint256 height);
    event OPERATOR(address operator);

    function addNode(address operator) onlyAdmin external {
        // [1] 对该operator的操作频率需满足条件
        require(block.number >= (modifys[operator] + modify_frequency), "modify fast");

        // [2] 添加operator
        _addNode(operator);

        // [3] 全局更新记录
        lastChanged = block.number;

        emit BLOCKNUMBER(block.number);
    }


    function _addNode(address _operator) internal {
        // [1] 判断operator是否存在
        require(!isOperatorExist(_operator),"operator exist");

        // [2] 更新白名单
        whiteTable[_operator] = State(block.number, true);

        // TODO for循环
        if (!contains(operatorKeys,_operator)) {
            operatorKeys.push(_operator);
        }

        // [3] 更新admin对该operator的操作记录
        modifys[_operator] = block.number;

    }

    function removeNode(address operator) onlyAdmin external {

        // [1] 对该operator的操作频率需满足条件
        require(block.number >= (modifys[operator] + modify_frequency), "modify fast");

        // [2] 判断operator是否存在
        require(isOperatorExist(operator),"operator doesn't exist");

        // [3] 更新黑名单
        blackTable[operator] = State(block.number, true);

        // [4] 全局更新记录
        lastChanged = block.number;

        // [5] 更新admin对该operator的操作记录
        modifys[operator] = block.number;

        emit BLOCKNUMBER(block.number);
    }

    function updateNodeConfig(string calldata pubkey, string calldata networkAddresses) external {

        // [1] 判断operator是否存在
        require(isOperatorExist(msg.sender),"operator doesn't exist");

        // [2] 判断所更新的配置信息是否已经在其他节点存在
        // require(strCompare(operator2pubkeys[msg.sender],pubkey) == 0, "doesn't match");

        // [3] 更新
        doUpdate(msg.sender, pubkey, networkAddresses);

        emit BLOCKNUMBER(block.number);

    }

    function doUpdate(address operator, string memory pubkey, string memory networkAddresses) internal {

        // [1] 版本号配置更新
        configTable[operator][block.number] = Config(pubkey, networkAddresses);
        versions[operator].push(block.number);

        // [2] 全局更新记录
        lastChanged = block.number;
    }


    // 获取p2p层面符合的operator集
    function getOperatorsForP2p() external view
    returns (address[] memory){
        return findAvailableOperatorForP2p();
    }

    // 获取共识层面符合的operator集
    function getOperatorForConsensus(uint256 sync_height, uint256 commit_height, uint256 target_height) external view
    returns (address[] memory) {
        return findAvailableOperatorForConsensus(sync_height, commit_height, target_height);
    }

    // for p2p
    function getAvailableNodesForP2p() external view
    returns (Config[] memory){

        address[] memory operators = findAvailableOperatorForP2p();

        Config[] memory configs = findAvailableConfigByOperators(operators);

        return configs;

    }

    function findAvailableConfigByOperators(address[] memory operators) internal view
    returns (Config[] memory){
        uint256 j = 0;
        for(uint256 i = 0; i<operators.length; i++) {
            if (versions[operators[i]].length != 0 ) {
                j++;
            }
        }

        Config[] memory res = new Config[](j);

        j = 0;
        for(uint256 i = 0; i<operators.length; i++) {
            if (versions[operators[i]].length != 0) {
                uint256 versionLength = versions[operators[i]].length;
                uint256 availableVersion = versions[operators[i]][versionLength-1];
                res[j++] = configTable[operators[i]][availableVersion];
            }
        }

        return res;
    }

    function findAvailableOperatorForP2p() internal view
    returns (address[] memory){
        uint256 j = 0;
        for (uint256 i = 0; i < operatorKeys.length; i++) {
            if (whiteTable[operatorKeys[i]].height < blackTable[operatorKeys[i]].height) {
                j++;
            }
        }

        address[] memory operators = new address[](operatorKeys.length - j);

        j = 0;
        for (uint256 i = 0; i < operatorKeys.length; i++) {
            if (whiteTable[operatorKeys[i]].height > blackTable[operatorKeys[i]].height) {
                operators[j++] = operatorKeys[i];
            }
        }

        return operators;
    }

    // for consensus  eg: 100, 30, 200
    function getAvailableNodesForConsensus(uint256 sync_height, uint256 commit_height) external view
    returns (Config[] memory){

        uint256 target_height = block.number;

        // find operators for consensus
        address[] memory operators = findAvailableOperatorForConsensus(sync_height, commit_height, target_height);

        // find configs for p2p
        Config[] memory configs = findAvailableConfigByOperators(operators, target_height-commit_height);

        return configs;



    }

    // find operators
    function findAvailableOperatorForConsensus(uint256 sync_height, uint256 commit_height, uint256 target_height) internal view
    returns (address[] memory){
        uint256 j = 0;
        for (uint256 i = 0; i < operatorKeys.length; i++) {

            if (whiteTable[operatorKeys[i]].isSet == true) {
                if (blackTable[operatorKeys[i]].isSet == false) {
                    if (whiteTable[operatorKeys[i]].height <= (target_height-commit_height) && whiteTable[operatorKeys[i]].height <= (target_height-sync_height)) {
                        j++;
                    }
                }

                else if(blackTable[operatorKeys[i]].height > whiteTable[operatorKeys[i]].height) {
                    if (blackTable[operatorKeys[i]].height <= (target_height-commit_height)) {
                        // remove
                    } else if(whiteTable[operatorKeys[i]].height <= (target_height-commit_height) && whiteTable[operatorKeys[i]].height <= (target_height-sync_height)){
                        j++;
                    }
                }
                else {
                    if(whiteTable[operatorKeys[i]].height <= (target_height-commit_height) && whiteTable[operatorKeys[i]].height <= (target_height-sync_height)){
                        j++;
                    }
                }
            }
        }

        address[] memory operators = new address[](j);
        j = 0;
        for (uint256 i = 0; i < operatorKeys.length; i++) {

            if (whiteTable[operatorKeys[i]].isSet == true) {
                if (blackTable[operatorKeys[i]].isSet == false) {
                    if (whiteTable[operatorKeys[i]].height <= (target_height-commit_height) && whiteTable[operatorKeys[i]].height <= (target_height-sync_height)) {
                        operators[j++] = operatorKeys[i];
                    }
                }

                else if(blackTable[operatorKeys[i]].height > whiteTable[operatorKeys[i]].height) {
                    if (blackTable[operatorKeys[i]].height <= (target_height-commit_height)) {
                        // remove
                    } else if(whiteTable[operatorKeys[i]].height <= (target_height-commit_height) && whiteTable[operatorKeys[i]].height <= (target_height-sync_height)){
                        operators[j++] = operatorKeys[i];
                    }
                }
                else {
                    if(whiteTable[operatorKeys[i]].height <= (target_height-commit_height) && whiteTable[operatorKeys[i]].height <= (target_height-sync_height)){
                        operators[j++] = operatorKeys[i];

                    }
                }
            }
        }

        return operators;

    }

    function findAvailableConfigByOperators(address[] memory operators, uint256 target_version) internal view
    returns (Config[] memory){

        uint256 j = 0;

        for(uint256 i = 0; i<operators.length; i++) {
            uint256 availableVersion = _getAvailableVersion(operators[i],target_version);
            if(availableVersion != 0) {
                j++;
            }
        }

        Config[] memory res = new Config[](j);

        j = 0;
        for(uint256 i = 0; i<operators.length; i++) {
            uint256 availableVersion = _getAvailableVersion(operators[i],target_version);
            if(availableVersion != 0) {
                Config memory temp = configTable[operators[i]][availableVersion];
                res[j++] = temp;
            }
        }
        return res;

    }

    function _getAvailableVersion(address key, uint256 target_version) internal view
    returns (uint256) {
        uint256[] storage version = versions[key];
        uint256 length = version.length;
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

    function getLastChanged() external view
    returns (uint256){
        return lastChanged;
    }

    function isOperatorExist(address operator) internal view
    returns (bool){
        if (whiteTable[operator].isSet == true) {
            if (blackTable[operator].isSet == false) {
                return true;
            } else if (whiteTable[operator].height > blackTable[operator].height){
                return true;
            }
        }

        return false;
    }

    function strCompare(string memory _a, string memory _b) internal pure returns (int) {
        bytes memory a = bytes(_a);
        bytes memory b = bytes(_b);
        uint minLength = a.length;
        if (b.length < minLength) minLength = b.length;
        for (uint i = 0; i < minLength; i ++)
            if (a[i] < b[i])
                return -1;
            else if (a[i] > b[i])
                return 1;
        if (a.length < b.length)
            return -1;
        else if (a.length > b.length)
            return 1;
        else
            return 0;
    }

    function contains(address[] memory array, address key) internal pure
    returns (bool){
        for (uint256 i = 0; i<array.length; i++) {
            if (array[i] == key) {
                return true;
            }
        }
        return false;
    }

}
