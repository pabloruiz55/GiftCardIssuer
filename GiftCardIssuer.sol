pragma solidity 0.4.19;

/**
 * @author Pablo Ruiz <me@pabloruiz.co>
 * @title GiftCardIssuer - A Gift Card contract to issue and accept gift cards
 */ 
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
    
    // Keeps track of the ether balance 
    uint public balance;
    
    // Card business rules variables
    uint public rule_Duration = 365 days;
    bool public rule_Rechargeable = false;
    uint public rule_MinValue = 1 wei;
    uint public rule_MaxValue = 100 ether;
    bool public rule_Transfereable = true;
    
    event E_GiftCardUsed(bytes32 _cardId, uint _dateOfUse, address _usedBy, uint _prodPrice);
    event E_GiftCardIssued(bytes32 _cardId, uint _dateOfIssue, address _issuer, address _beneficiary, uint _value);

    
    function GiftCardIssuer() public {
        owner = msg.sender;
    }
    
    /**
     * @dev modifies the business rules of newly issued gift cards
     * @param _rechargeable whether or not the gift car can be recharged
     * @param _transfereable whether or not the gift card can be transferred
     * @param _duration is how long the gift card lasts
     * @param _minValue is the minimum ether that has to be sent in order to issue the card
     * @param _maxValue is the maximum ether that can be sent in order to issue the card
     */
    function setGiftCardRules(
        bool _rechargeable,
        bool _transfereable,
        uint _duration,
        uint _minValue,
        uint _maxValue
        ) public {
        require(msg.sender == owner);
        require(_duration >= 1 days);
        require(_minValue > 0);
        require(_maxValue >= _minValue);
        
        rule_Rechargeable = _rechargeable;
        rule_Transfereable = _transfereable;
        rule_Duration = _duration;
        rule_MinValue = _minValue;
        rule_MaxValue = _maxValue;
    }
    
    /**
     * @dev issues a new gift card with the business rules set.
     * @param _cardId is the id that the issuer wants to set for the card (must be unique)
     * @param _beneficiary is the account that will be able to use the cards
     */
    function issueGiftCard(bytes32 _cardId, address _beneficiary) public payable {
        require(msg.value > 0);
        require(cards[_cardId].issueDate == 0);
        require(msg.value >= rule_MinValue);
        require(msg.value <= rule_MaxValue);
        
        cards[_cardId].value = msg.value;
        cards[_cardId].beneficiary = _beneficiary;
        cards[_cardId].generatedBy = msg.sender;
        cards[_cardId].issueDate = now;
        cards[_cardId].validThru = now + rule_Duration;
        cards[_cardId].rechargeable = rule_Rechargeable;
        cards[_cardId].transfereable = rule_Transfereable;
        
        // add value to merchant balance
        balance += msg.value;
        
        E_GiftCardIssued(_cardId, now, msg.sender, _beneficiary,msg.value);
    }
    
    /**
     * @dev transfers the gift card to another beneficiary if allowd by business rules
     * @param _cardId is the id of the card
     * @param _newBeneficiary is the new beneficary of the card 
     */
    function transferGiftCardTo(bytes32 _cardId, address _newBeneficiary) public {
        require(msg.sender == cards[_cardId].beneficiary);
        require(cards[_cardId].issueDate > 0);
        require(cards[_cardId].transfereable);
        require(_newBeneficiary != address(0));
        
        cards[_cardId].beneficiary = _newBeneficiary;
    }
    
    /** @dev adds funds to the gift card if the business rules allow it 
     * @param _cardId is the id of the card 
     */
    function addFundsToGiftCard(bytes32 _cardId) public payable{
        require(cards[_cardId].rechargeable);
        require(msg.value > 0);
        require(cards[_cardId].issueDate > 0);
        require(msg.value >= rule_MinValue);
        require(msg.value <= rule_MaxValue);
        
        cards[_cardId].value += msg.value;
        cards[_cardId].validThru = now + rule_Duration; //Extend duration
        
        // add value to merchant balance
        balance += msg.value;
    }
    
    /**
     * @dev uses the gift card and substracts the corresponding balance from it to pay for a product
     * @param _cardId is the id of the card 
     * @param _prodPrice is the price of the product being purchased (how much balance will be substracted from the card)
     */
    function useGiftCard(bytes32 _cardId, uint _prodPrice) public returns (bool){
        
        // Gift card can only be used by the account it was issued to
        require(msg.sender == cards[_cardId].beneficiary);
        
        // card must exist
        require(cards[_cardId].issueDate > 0);
        
        // Card must not have expired
        require(now <= cards[_cardId].validThru);
        
        // Card should have enough funds to cover the purchase
        require(cards[_cardId].value >= _prodPrice);
        
        // remove value from card balance
        cards[_cardId].value -= _prodPrice;
        
        E_GiftCardUsed(_cardId, now, cards[_cardId].beneficiary, _prodPrice);
    
        return (true);
    }
    
    /**
     * @dev allows the owner of the contract to withdraw the funds sent to it 
     * when gift cards are purchased 
     */
    function withdrawMerchantBalance() public {
        require(msg.sender == owner);
        
        uint fundToWithdraw = balance;
        balance = 0;
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
