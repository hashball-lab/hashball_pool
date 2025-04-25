// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface MyHashBall {
    function get_pool_money_back(address _addr, uint256 _amount) external;
}

interface MyCommittee {
    function get_current_epoch_starttime() external view returns(uint256, uint256);
}

contract Pools {

    MyHashBall public myHashBall;
    MyCommittee public mycommittee;

    struct Pool{
        uint256 pool_money;
        uint256 pool_quantity;
    }

    struct Deposite{
        uint256 my_pool_quantity;
    }

    Pool[3] private pools;//epoch 1=>pool0; 2=>1;3=>2;4=>0; (epoch - 1)%3;
    mapping(address =>Deposite[3]) private my_deposite;
    
    mapping (address => bool) private authorize_drawwinner;//authorize

    address private owner;  
    address private hashball_contract_address; 
    bool private initialized;
    uint256 constant public BET_DIFF = 60*60*46;
    uint256 constant public CLAIM_FEE = 995;//0.5% fee

    modifier onlyOwner(){
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier onlyDrawWinner(){
        require(authorize_drawwinner[msg.sender], "not authorize");
        _;
    }

    function initialize(address _owner) public{
        require(!initialized, "already initialized");
        initialized = true;
        owner = _owner;
    }

    function set_mycommittee(address _mycommittee) public onlyOwner{
        mycommittee = MyCommittee(_mycommittee);
    }

    function set_hashball(address _myhashball) public onlyOwner{
        myHashBall = MyHashBall(_myhashball);
        hashball_contract_address = _myhashball;
    }

    function set_authorize_drawwinner(address _myaddress, bool _true_false) public onlyOwner{
        authorize_drawwinner[_myaddress] = _true_false;
    }

    function provide_liquid(uint256 _amount) public payable{
        (uint256 epoch, uint256 starttime) = mycommittee.get_current_epoch_starttime();
        require(epoch > 0, 'not start');
        require(starttime > 0, 'epoch not start');
        require(block.timestamp - starttime < BET_DIFF, 'time exceed');
        uint256 curren_pool_index = (epoch - 1) % 3;
        require(_amount > 0, 'amount should greater than 0');
        require(msg.value >= _amount, "not enough pay");
        (bool success, ) = (hashball_contract_address).call{value: _amount}("");
        if(!success){
            revert('call failed');
        }

        if(pools[curren_pool_index].pool_quantity == 0){
            pools[curren_pool_index].pool_money += _amount;
            pools[curren_pool_index].pool_quantity = _amount;
            my_deposite[msg.sender][curren_pool_index].my_pool_quantity += _amount;//add
        }else{
            uint256 my_quantity = (pools[curren_pool_index].pool_quantity * _amount) / pools[curren_pool_index].pool_money;
            pools[curren_pool_index].pool_money += _amount;
            pools[curren_pool_index].pool_quantity += my_quantity;
            my_deposite[msg.sender][curren_pool_index].my_pool_quantity += my_quantity;
        }
    }

    function remove_liquid(uint256 _pool_quantity) public{
        (uint256 epoch, uint256 starttime) = mycommittee.get_current_epoch_starttime();
        require(epoch > 0, 'not start');
        require(starttime > 0, 'epoch not start');
        require(_pool_quantity > 0, 'quantity not allow');
        require(block.timestamp - starttime < BET_DIFF, 'time exceed');
        uint256 curren_pool_index = (epoch - 1) % 3;
        require(pools[curren_pool_index].pool_quantity >= _pool_quantity, 'pool quantity exceed');
        require(my_deposite[msg.sender][curren_pool_index].my_pool_quantity >= _pool_quantity, 'my pool quantity exceed');
        my_deposite[msg.sender][curren_pool_index].my_pool_quantity -= _pool_quantity;
        uint256 back_money = (pools[curren_pool_index].pool_money * _pool_quantity*CLAIM_FEE/1000)/pools[curren_pool_index].pool_quantity;
        pools[curren_pool_index].pool_money -= back_money;
        pools[curren_pool_index].pool_quantity -= _pool_quantity;

        myHashBall.get_pool_money_back(msg.sender, back_money);
    }

    function get_pool_money(uint256 _index) public view returns(uint256){
        return pools[_index].pool_money;
    }

    function change_pool_money(uint256 _index, uint256 _money) external onlyDrawWinner{
        pools[_index].pool_money = _money;
    }

    function add_pool_money(uint256 _index, uint256 _money) external onlyDrawWinner{
        pools[_index].pool_money += _money;
    }

    function get_liquid_pool() public view returns(Pool[3] memory){
        return pools;
    }

}
