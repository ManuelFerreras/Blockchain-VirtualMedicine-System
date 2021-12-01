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


    function getClientLabHistory() public view returns (labRequestedServices[] memory) {

        return labClientHistory;

    }


    function getClientHistory(string memory _service) public view returns (string memory, uint256) {

        return (clientHistory[_service].requestedServiceName, clientHistory[_service].requestedServicePrice);
        
    }


    function checkClientServiceState (string memory _service) public view returns (bool) {

        return clientHistory[_service].serviceState;

    }

}




contract Laboratory is BasicOperations {

    // -------------------------------------------- Declaration -------------------------------------------- //


    address public labAddress;
    address insuranceAddress;

    // Constructor
    constructor(address _labOwner, address _insurance) {

        labAddress = _labOwner;
        insuranceAddress = _insurance;

    }

}