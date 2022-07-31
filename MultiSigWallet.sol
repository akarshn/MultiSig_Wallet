// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MultiSigWallet{

    event Deposit(address indexed sender,uint amount);
    event Submit(uint indexed txtId);
    event Approve(address indexed Owner, uint indexed txtId);
    event Revoke(address indexed Owner, uint indexed txtId);
    event Execute(uint indexed txtId);

    struct Transaction{
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint public required;

    Transaction[] public transactions;
    mapping(uint => mapping(address =>bool)) public approved;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not sender");
        _;
    }

    modifier txExists(uint _txtId) {
        require(_txtId < transactions.length, "tx does not exist");
        _;
    }

    modifier notApproved(uint _txtId){
        require(!approved[_txtId][msg.sender], "tx already approved");
        _;
    }

    modifier notExecuted(uint _txtId) {
        require(transactions[_txtId].executed, "tx already executed");
        _;
    }

    constructor(address[] memory _owners, uint _required) {
        require(_owners.length > 0, "owners required");
        require(
            _required > 0 && _required <= _owners.length,
            "invalid required number of owners"
        );

        for (uint i; i<_owners.length; i++) {
            address Owner = _owners[i];

            require(Owner != address(0), "invalid owner" );
            require(!isOwner[Owner], "Owner is not unique");

            isOwner[Owner] = true;
            owners.push(Owner);

        }

        required = _required;
    }

    receive() external payable {
        emit Deposit(msg.sender,msg.value);
    }

    function submit(address _to,uint _value, bytes calldata _data)
        external
        onlyOwner
    {
        transactions.push(Transaction({
            to : _to,
            value: _value,
            data: _data,
            executed: false
        }));

        emit Submit(transactions.length - 1);
    }

    function approve(uint _txtId)
        external
        onlyOwner
        txExists(_txtId)
        notApproved(_txtId)
        notExecuted(_txtId)
    {
        approved[_txtId][msg.sender] = true;
        emit Approve(msg.sender, _txtId);
    }

    function _getApprovalCount(uint _txtId) private view returns (uint count) {
        for(uint i; i<owners.length; i++){
            if(approved[_txtId][owners[i]]) {
                count+=1;
            }
        }
    }

    function execute (uint _txtId) external txExists(_txtId) notExecuted(_txtId) {
        require(_getApprovalCount(_txtId) >= required, "approval < required");
        Transaction storage transaction = transactions[_txtId];

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit Execute(_txtId);
    }

    function revoek(uint _txtId) external onlyOwner txExists(_txtId) notExecuted(_txtId) {
        require(approved[_txtId][msg.sender], "tx not approved");
        approved[_txtId][msg.sender] = false;
        emit Revoke(msg.sender, _txtId);
    }

}
