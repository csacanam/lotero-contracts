// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract Lotero {

    struct Player {
        bool voted;  // if true, that person already voted
        uint betId;   // index of the bet
        uint256 amount; // player bet

    }

    struct Bet {
        uint256 amount; // number of money accumulated in the bet
        mapping(address => Player) players; //map of players in the bet
        mapping(uint8 => address []) playersByChoosenNumber; //map of addresses by bet number
        mapping(uint8 => uint256) amountByChoosenNumber;
        uint256 numberOfPlayers; // number of players in the bet
        ValidNumber winnerNumber;
    }

    enum ValidNumber {ZERO, ONE, TWO, THREE, FOUR, FIVE, SIX, SEVEN, EIGHT, NINE, NOT_VALID}


    Bet[] public bets;

    uint8 public constant MIN_WIN_MULTIPLIER = 2;

    uint8 public constant MAX_WIN_MULTIPLIER = 5;

    uint256 public activeBet;

    constructor () payable {
        Bet storage firstBet = bets.push();
        firstBet.amount = 0;
        firstBet.numberOfPlayers = 0;
        firstBet.winnerNumber = ValidNumber.NOT_VALID;
        
        activeBet = 0;
    }

    /**
    * @dev Add money to the bet with index betId
    * @param betId index of bet in the bets array
    */
    function bet(uint betId, uint8 betNumber) public payable isValidNumber(betNumber) checkBetCouldBePayed(betId, msg.value) {
        //Bet should be greater than 0
        require(msg.value > 0, "Amount should be greater than 0");

        //Get current player
        Player storage currentPlayer = bets[betId].players[msg.sender];
        require(!currentPlayer.voted, "Already in the current bet.");

        //Update player state
        currentPlayer.voted = true;
        currentPlayer.betId = betId;
        currentPlayer.amount = msg.value;

        //Update bet
        bets[betId].amount += currentPlayer.amount;
        bets[betId].numberOfPlayers++;
        bets[betId].playersByChoosenNumber[betNumber].push(msg.sender);
        bets[betId].amountByChoosenNumber[betNumber] += currentPlayer.amount;
    }

    /**
    *@dev Get number of players in bet with given index
    *@param betId the bet index
    */
    function getNumberOfPlayersInBet(uint betId) public view returns(uint256) {
        return bets[betId].numberOfPlayers;
    }

    /**
    *@dev Get amount of money in bet with index betId
    *@param betId the bet index
    */
    function getTotalMoneyInBet(uint betId) public view returns(uint256) {
        return bets[betId].amount;
    }

    /**
    *@dev Get total money in contract
    */
    function getMoneyInContract() public view returns(uint256) {
        return address(this).balance;
    }

    /**
    *@dev Get players who choose choosenNumber in bet with index betId
    *@param betId the bet index
    *@param choosenNumber the choosen number
    */
    function getPlayersWhoChooseNumberInBet(uint betId, uint8 choosenNumber) public view returns(address[] memory) {
        return bets[betId].playersByChoosenNumber[choosenNumber];
    }

    /**
    *@dev Get available quota to add in the bet
    *@param betId the bet index
    */
    function getAvailableQuotaInBet(uint betId) public view returns(uint256) {
        return (address(this).balance - (getMaxBetAmountInBet(betId)*MIN_WIN_MULTIPLIER))/MIN_WIN_MULTIPLIER;
    }

    /**
    *@dev Close bet, pay to winners and increase the bet index.
    *
    */
    function closeBet(ValidNumber winningNumber) public payable currentBetIsActive isValidNumber(uint8(winningNumber)){

        address [] memory winners = bets[activeBet].playersByChoosenNumber[uint8(winningNumber)];

        //Get de winning multiplier (from 2 to 5)
        uint8 winningMultiplier = getWinnerMultiplier(winningNumber);

        //Pay to winners
        for(uint8 i = 0; i < winners.length; i++) { 
            address payable winner = payable(winners[i]);
            winner.transfer(bets[activeBet].players[winner].amount * winningMultiplier);
        }

        //Increase bet index
        activeBet++;

        //Create new bet
        Bet storage nextBet = bets.push();
        nextBet.amount = 0;
        nextBet.numberOfPlayers = 0;
        nextBet.winnerNumber = ValidNumber.NOT_VALID;

    }

    /**
    *@dev Get current winner multipler for current bet
    */
    function getWinnerMultiplier(ValidNumber winningNumber) public view isValidNumber(uint8(winningNumber)) returns (uint8) {

        uint8 currentMultiplier = MAX_WIN_MULTIPLIER;

        while(currentMultiplier >= MIN_WIN_MULTIPLIER){
            if (bets[activeBet].amountByChoosenNumber[uint8(winningNumber)] * currentMultiplier < address(this).balance){
                break;
            }else{
                currentMultiplier--;
            }
        }

        return currentMultiplier;
    }

    /**
    *@dev Get current min win multipler for current bet
    */
    function getMinMultiplier() public view returns (uint8) {

        uint8 currentMultiplier = MAX_WIN_MULTIPLIER;

        while(currentMultiplier >= MIN_WIN_MULTIPLIER){
            if (getMaxBetAmountInBet(activeBet) * currentMultiplier < address(this).balance){
                break;
            }else{
                currentMultiplier--;
            }
        }

        return currentMultiplier;
    }

    /**
    *@dev Get current max win multipler for current bet
    */
    function getMaxMultiplier() public view returns (uint8) {

        uint8 currentMultiplier = MAX_WIN_MULTIPLIER;

        while(currentMultiplier >= MIN_WIN_MULTIPLIER){
            if (getMinBetAmountInBet(activeBet) * currentMultiplier < address(this).balance){
                break;
            }else{
                currentMultiplier--;
            }
        }

        return currentMultiplier;
    }

    /**
    *@dev Get max amount bet on any number
    *@param betId the bet index
    */
    function getMaxBetAmountInBet(uint betId) public view returns(uint256) {
        uint256 maxAmount = 0;

        //Loop from 0 to 9
        for(uint8 i = 0; i < 10; i++) {  
            if(bets[betId].amountByChoosenNumber[i] > maxAmount) {
                maxAmount = bets[betId].amountByChoosenNumber[i];
            }
        }

        return maxAmount;
    }

    /**
    *@dev Get min amount bet on any number
    *@param betId the bet index
    */
    function getMinBetAmountInBet(uint betId) public view returns(uint256) {
        uint256 minAmount = bets[betId].amountByChoosenNumber[0];

        //Loop from 0 to 9
        for(uint8 i = 1; i < 10; i++) {  
            if(bets[betId].amountByChoosenNumber[i] < minAmount) {
                minAmount = bets[betId].amountByChoosenNumber[i];
            }
        }

        return minAmount;
    }

    /**
    *@dev Get total money in bet with index betId who choose choosenNumber
    *@param betId the bet index
    *@param choosenNumber the choosen number
    */
    function getTotalMoneyBetWithNumber(uint betId, uint8 choosenNumber) private view returns(uint256) {
        return bets[betId].amountByChoosenNumber[choosenNumber];
    }

    /**
    *@dev Check if number is between 0 and 9
    *@param number the number to be validated
    */
    modifier isValidNumber(uint8 number) {
        require(number >= 0 && number <=9, "Not a valid number");
        _;
    }

    /**
    *@dev Check if the bet can be added
    @param betId bet index
    *@param amount the amount to be validated
    */
    modifier checkBetCouldBePayed(uint betId, uint256 amount) {
        uint256 possibleNewAmount = amount + getMaxBetAmountInBet(betId);
        require(address(this).balance >= possibleNewAmount * MIN_WIN_MULTIPLIER, "Not enough money in balance to add this bet");
        _;
    }

    /**
    *@dev Check if current bet is active
    */
    modifier currentBetIsActive(){
        require(bets[activeBet].winnerNumber == ValidNumber.NOT_VALID, "Current bet is not active");
        _;
    }


}