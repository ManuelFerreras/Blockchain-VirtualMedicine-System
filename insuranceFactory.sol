pragma solidity >= 0.8.0;

// SPDX-License-Identifier: UNLICENSED

import "./SafeMath.sol";
import "./ERC20.sol";
import "./BasicOperations.sol";


// Insurance contract.
contract InsuranceFactory is BasicOperations {
    using SafeMath for uint256;



    // -------------------------------------------- Instantiation -------------------------------------------- //


    // Token
    ERC20Basic private token;

    // Addresses
    address insuranceAddress; // Insurance
    address payable public insuranceWallet; // Aseguradora

    // Structs
    struct client {

        address clientAddress;
        address contractAddress;
        bool clientAuth;

    }
    struct service {

        string serviceName;
        uint servicePrice;
        bool serviceState;

    }
    struct lab {

        address labContractAddress;
        bool labValidation;

    }

    // Mappings and arrays
    mapping (address => client) public clientsMap;
    mapping (string => service) public servicesMap;
    mapping (address => lab) public labsMap;

    string [] servicesNames;
    address [] labsAddresses;
    address [] clients;

    // Constructor
    constructor () {

        // Initiate token
        token = new ERC20Basic(10000);

        // Set Addresses
        insuranceAddress = address(this);
        insuranceWallet = payable(msg.sender);

    }

    // Only Insuranced
    function onlyInsurancedFunction(address _insuranced) public view {
        require(clientsMap[_insuranced].clientAuth == true, "Not the authorized client.");
    }

    // Modifiers
    modifier onlyInsuranced(address _insuranced) {
        onlyInsurancedFunction(_insuranced);
        _;
    }

    modifier onlyInsurance() {
        require(msg.sender == insuranceWallet, "Not Authorized insurance");
        _;
    }

    modifier inurancedOrInsurance(address _clientAddress, address _entrantAddress) {
        require( (clientsMap[_entrantAddress].clientAuth == true && _clientAddress == _entrantAddress) || insuranceAddress == _entrantAddress, "Only insuranced or insurance" );
        _;
    }

    // Events
    event tokensBoughtEvent(uint256);
    event serviceGivenEvent(address, string, uint256);
    event newLabEvent(address, address);
    event newClientEvent(address, address);
    event delClientEvent(address);
    event newServiceEvent(string, uint256);
    event delServiceEvent(string);


    // -------------------------------------------- Logic -------------------------------------------- //

    function newLab() public {

        // Add lab to array
        labsAddresses.push(msg.sender);

        // Gets the address from a new Lab.
        address _labAddress = address(new Laboratory(msg.sender, insuranceAddress));

        // Adds new lab to owner labs map.
        labsMap[msg.sender] = lab(_labAddress, true);

        // Trigger Event
        emit newLabEvent(msg.sender, _labAddress);

    }


    function createInsuranceContract() public {

        // Adds client to array.
        clients.push(msg.sender);

        // Gets new contract address.
        address _clientAddress = address(new InsuranceHealthRecord(msg.sender, token, insuranceAddress, insuranceWallet));

        // Creates new client info in map.
        clientsMap[msg.sender] = client(msg.sender, _clientAddress, true);

        // Trigger Event
        emit newClientEvent(msg.sender, _clientAddress);

    }


    function getLabs() public view onlyInsurance() returns(address[] memory) {

        return labsAddresses;

    }


    function getClients() public view onlyInsurance returns (address[] memory) {

        return clients;

    }

    function getClientHistory(address _clientAddress, address _requester) public view inurancedOrInsurance(_clientAddress, _requester) returns (string memory) {

        string memory _history = "";

        address _clientContractAddress = clientsMap[_clientAddress].contractAddress;

        for (uint256 i = 0; i < servicesNames.length; i++) {
            if (servicesMap[servicesNames[i]].serviceState && InsuranceHealthRecord(_clientContractAddress).checkClientServiceState(servicesNames[i])) {
                (string memory _serviceName, uint _servicePrice) = InsuranceHealthRecord(_clientContractAddress).getClientHistory(servicesNames[i]);

                _history = string(abi.encodePacked(_history, " (", _serviceName, ", ", uint2str(_servicePrice), ") ------"));
            }
        }

        return _history;

    }

    function revokeClient(address _client) public onlyInsurance {

        // Revoke Auth
        clientsMap[_client].clientAuth = false;

        // Destroys client smart contract
        InsuranceHealthRecord(clientsMap[_client].contractAddress).revoke();

        // Trigger Event
        emit delClientEvent(_client);

    }

    function createService(string memory _serviceName, uint256 _servicePrice) public onlyInsurance {

        // Creates service
        servicesMap[_serviceName] = service(_serviceName, _servicePrice, true);

        // Pushes its name to services names array
        servicesNames.push(_serviceName);

        // Triggers Event
        emit newServiceEvent(_serviceName, _servicePrice);

    }

    function revokeService(string memory _serviceName) public onlyInsurance {

        // Check if service is not revoked.
        require(getServiceState(_serviceName), "Service Already Revoked");

        // Revokes service
        servicesMap[_serviceName].serviceState = false;

        // Triggers Event
        emit delServiceEvent(_serviceName);

    }

    function getServiceState(string memory _serviceName) public view returns(bool) {
        return servicesMap[_serviceName].serviceState;
    }

    function getServicePrice(string memory _serviceName) public view returns(uint256) {
        
        // Check if service is not revoked.
        require(getServiceState(_serviceName), "Service Already Revoked");

        return servicesMap[_serviceName].servicePrice;

    }

    function getActiveServices() public view returns(string[] memory) {

        string [] memory _activeServices = new string[](servicesNames.length);

        uint256 _counter;

        for (uint256 i = 0; i < servicesNames.length; i++) {
            if(getServiceState(servicesNames[i])) {
                _activeServices[_counter] = servicesNames[i];
                _counter ++;
            }
        }

        return _activeServices;

    }

    // -------------------------------------------- Tokens -------------------------------------------- //

    function buyTokens(address _client, uint256 _amount) public payable onlyInsuranced(_client) {

        // Get Contract Tokens Balance
        uint256 _balance = balanceOf();

        // Check if there are enough tokens to sell
        require(_amount <= _balance, "Not Enough Tokens to Sell");

        // Transfer Tokens
        token.transferFrom(address(this), msg.sender, _amount);

        emit tokensBoughtEvent(_amount);

    }

    function balanceOf() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function mintTokens(uint256 _amount) public onlyInsurance {
        token.increaseTotalSupply(_amount);
    }

}



contract InsuranceHealthRecord is BasicOperations {

    // Owner State
    enum State { on, off }

    // Owner Struct
    struct Owner {
        address ownerAddress;
        uint256 ownerBalance;
        State state;
        IERC20 tokens;
        address insuranceAddress;
        address payable insuranceWallet;
    }

    // Requested service by the client
    struct requestedServices {
        string requestedServiceName;
        uint256 requestedServicePrice;
        bool serviceState;
    }

    // Requested service by the lab
    struct labRequestedServices {
        string requestedServiceName;
        uint256 requestedServicePrice;
        address labAddress;
    }

    // Store clients requests
    mapping (string => requestedServices) clientHistory;

    // Labs requests.
    labRequestedServices[] labClientHistory;

    // Requested services by the client.
    requestedServices[] clientRequestedServices;

    // New owner
    Owner owner;

    // Constructor
    constructor(address _owner, IERC20 _token, address _insuranceAddress, address payable _insuranceWallet) {

        // Setup the owner struct.
        owner.ownerAddress = _owner;
        owner.ownerBalance = 0;
        owner.state = State.on;
        owner.tokens = _token;
        owner.insuranceAddress = _insuranceAddress;
        owner.insuranceWallet = _insuranceWallet;

    }

    // Events
    event selfDestructEvent(address);
    event sellTokensEvent(address, uint256);
    event paidServiceEvent(address, string, uint256);
    event serviceRequestLabEvent(address, address, string);


    // -------------------------------------------- Logic -------------------------------------------- //

    modifier onlyInsurance() {
        require(msg.sender == owner.ownerAddress, "Not the owner");
        _;
    }


    function getClientLabHistory() public view returns (labRequestedServices[] memory) {

        return labClientHistory;

    }


    function getClientHistory(string memory _service) public view returns (string memory, uint256) {

        return (clientHistory[_service].requestedServiceName, clientHistory[_service].requestedServicePrice);
        
    }


    function checkClientServiceState (string memory _service) public view returns (bool) {

        return clientHistory[_service].serviceState;

    }


    function revoke() public onlyInsurance {

        // Destroy Smart Contract
        emit selfDestructEvent(msg.sender);
        selfdestruct(payable(msg.sender));

    }


    // -------------------------------------------- Tokens -------------------------------------------- //

    function buyTokens(uint256 _amount) public payable onlyInsurance {

        uint256 _tokensCost = getTokensPrice(_amount);

        require(msg.value >= _tokensCost, "Not enough ethers sent");

        uint256 returnValue = msg.value - _tokensCost;

        payable(msg.sender).transfer(returnValue);

        InsuranceFactory(owner.insuranceAddress).buyTokens(msg.sender, _amount);

    }

    function balanceOf() public view onlyInsurance returns(uint256) {
        return(owner.tokens.balanceOf(address(this)));
    }

    function sellTokens(uint256 _amount) public payable onlyInsurance {

        require(_amount < balanceOf(), "Not Enough tokens");

        owner.tokens.transfer(owner.insuranceWallet, _amount);

        payable(msg.sender).transfer(getTokensPrice(_amount));

        emit sellTokensEvent(msg.sender, _amount);

    }


    // -------------------------------------------- Services -------------------------------------------- //

    function requestService(string memory _serviceName) public onlyInsurance {

        require(InsuranceFactory(owner.insuranceAddress).getServiceState(_serviceName), "Service is revoked");

        uint256 _serviceCost = InsuranceFactory(owner.insuranceAddress).getServicePrice(_serviceName);

        require(balanceOf() > _serviceCost, "Not Enough Balance");

        owner.tokens.transfer(owner.insuranceWallet, _serviceCost);

        clientHistory[_serviceName] = requestedServices(_serviceName, _serviceCost, true);

        emit paidServiceEvent(msg.sender, _serviceName, _serviceCost);

    }

    function requestServiceLab(address _labAddress, string memory _serviceName) public payable onlyInsurance {

        Laboratory _lab = Laboratory(_labAddress);

        require(msg.value == _lab.getServicePrice(_serviceName) * 1 ether, "Not enough ether sent");

        _lab.giveService(msg.sender, _serviceName);

        payable(_lab.labAddress()).transfer(_lab.getServicePrice(_serviceName));

        labClientHistory.push(labRequestedServices(_serviceName, _lab.getServicePrice(_serviceName), _labAddress));

        emit serviceRequestLabEvent(_labAddress, msg.sender, _serviceName);

    }

}




contract Laboratory is BasicOperations {

    // -------------------------------------------- Declaration -------------------------------------------- //

    // Addresses
    address public labAddress;
    address insuranceAddress;

    // Structs
    struct result {
        string diagnostic;
        string ipfsCode;
    }

    struct labService {
        string serviceName;
        uint256 servicePrice;
        bool state;
    }



    // client => service
    mapping (address => string) serviceRequestedByClient;
    address[] servicesRequests;
    mapping (address => result) resultsFromLab;
    mapping (string => labService) labServices;
    string[] servicesNames;

    // Events
    event serviceWorkingEvent(string, uint);
    event giveServiceEvent(address, string);

    // Constructor
    constructor(address _labOwner, address _insurance) {
        labAddress = _labOwner;
        insuranceAddress = _insurance;
    }


    // -------------------------------------------- Logic -------------------------------------------- //

    modifier onlyLab() {
        require(msg.sender == labAddress, "Not The Owner");
        _;
    }


    function getServicePrice(string memory _serviceName) public view returns(uint256) {
        return labServices[_serviceName].servicePrice;
    }

    function giveService(address _client, string memory _serviceName) public {

        InsuranceFactory(insuranceAddress).onlyInsurancedFunction(_client);

        require(labServices[_serviceName].state, "Service not Available");

        serviceRequestedByClient[_client] = _serviceName;

        servicesRequests.push(_client);

        emit giveServiceEvent(_client, _serviceName);

    }

    function getServices() public view returns (string[] memory) {
        return servicesNames;
    }

    function newLabService(string memory _serviceName, uint256 _servicePrice) public onlyLab {

        labServices[_serviceName] = labService(_serviceName, _servicePrice, true);

        servicesNames.push(_serviceName);

        emit serviceWorkingEvent(_serviceName, _servicePrice);

    }

    function assignResult(address _client, string memory _diagnostic, string memory _ipfsCode) public onlyLab {
        resultsFromLab[_client] = result(_diagnostic, _ipfsCode);
    }

    function getResults(address _client) public view returns (string memory, string memory) {
        return (resultsFromLab[_client].diagnostic, resultsFromLab[_client].diagnostic);
    }

}