pragma solidity 0.4.19;

contract GiftCardIssuer {
    
    struct Card {
        uint value;
        uint issueDate;
        uint validThru;
        address beneficiary;
        address generatedBy;
        bool rechargeable;
        bool transfereable;
    }
    
    address owner;
    
    mapping (bytes32 => Card) public cards;
    
    uint public merchantBalance;
    
    // Card rules variables
    uint public rule_Duration = 365 days;
    bool public rule_Rechargeable = false;
    uint public rule_MinValue = 1 wei;
    uint public rule_MaxValue = 100 ether;
    bool public rule_Transfereable = true;
    
    function GiftCardIssuer() public {
        owner = msg.sender;
    }
    
    function setGiftCardRules(
        bool _rechargeable,
        bool _transfereable,
        uint _duration,
        uint _minValue,
        uint _maxValue
        ) public {
        require(msg.sender == owner);
        
        rule_Rechargeable = _rechargeable;
        rule_Transfereable = _transfereable;
        rule_Duration = _duration;
        rule_MinValue = _minValue;
        rule_MaxValue = _maxValue;
    }
    
    function generateGiftCard(bytes32 _id, address _beneficiary) public payable {
        require(msg.value > 0);
        require(cards[_id].issueDate > 0);
        require(msg.value >= rule_MinValue);
        require(msg.value <= rule_MaxValue);
        
        cards[_id].value = msg.value; // TBD FEES
        cards[_id].beneficiary = _beneficiary;
        cards[_id].generatedBy = msg.sender;
        cards[_id].issueDate = now;
        cards[_id].validThru = now + rule_Duration;
        cards[_id].rechargeable = rule_Rechargeable;
        cards[_id].transfereable = rule_Transfereable;
        
        // add value to merchant balance
        merchantBalance += msg.value;
    }
    
    function transferGiftCardTo(bytes32 _id, address _newBeneficiary) public {
        require(msg.sender == cards[_id].beneficiary);
        require(cards[_id].transfereable);
        require(_newBeneficiary != address(0));
        
        cards[_id].beneficiary = _newBeneficiary;
    }
    
    function addFundsToGiftCard(bytes32 _id) public payable{
        require(msg.value > 0);
        require(cards[_id].issueDate > 0);
        require(msg.value >= rule_MinValue);
        require(msg.value <= rule_MaxValue);
        
        cards[_id].value += msg.value; // TBD FEES
        cards[_id].validThru = now + rule_Duration; //Extend duration
        
        // add value to merchant balance
        merchantBalance += msg.value;
    }
    
    function useGiftCard(bytes32 _id, uint _prodPrice) public returns (bool){
        
        // Gift card can only be used by the account it was issued to
        require(msg.sender == cards[_id].beneficiary);
        
        // card must exist
        require(cards[_id].issueDate > 0);
        
        // Card must not have expired
        require(now <= cards[_id].validThru);
        
        // Card should have enough funds to cover the purchase
        require(cards[_id].value >= _prodPrice);
        
        // remove value from card balance
        cards[_id].value -= _prodPrice;
    
        return (true);
        
    }
    
    function withdrawMerchantBalance() public {
        require(msg.sender == owner);
        
        uint fundToWithdraw = merchantBalance;
        merchantBalance = 0;
        owner.transfer(fundToWithdraw);
    }
}

contract Store is GiftCardIssuer {
    
    uint itemPrice = 1 ether;
    
    mapping(address => uint) public itemsBought;
    
    function buyWithGiftCard(bytes32 _cardId) public {
        // Try to buy the product with the gift card provided
        require(useGiftCard(_cardId, itemPrice));
        
        itemsBought[msg.sender]++;
    }
    
    function buyWithEther() public payable {
        require(msg.value == itemPrice);
        
        itemsBought[msg.sender]++;
    }   
}
