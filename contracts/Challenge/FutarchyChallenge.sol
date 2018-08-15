pragma solidity ^0.4.24;
import '@gnosis.pm/gnosis-core-contracts/contracts/Oracles/FutarchyOracleFactory.sol';
import './Oracles/CentralizedTimedOracleFactory.sol';
import '@gnosis.pm/gnosis-core-contracts/contracts/MarketMakers/LMSRMarketMaker.sol';
import '@gnosis.pm/gnosis-core-contracts/contracts/Tokens/Token.sol';
import "zeppelin/math/SafeMath.sol";
import "./ChallengeInterface.sol";

contract  FutarchyChallenge is ChallengeInterface {

  event _Started(address challenger, uint stakeAmount, address futarchyOracleAddress);
  event _Funded(address challenger, uint stakeAmount, address futarchyOracleAddress);

  // ============
  // STATE:
  // ============
  // GLOBAL VARIABLES

  address public challenger;         // the address of the challenger
  address public listingOwner;       // the address of the listingOwner
  bool public isStarted;             // true if challenger has executed start()
  uint public stakeAmount;           // number of tokens to stake for either party during challenge
  uint public tradingPeriod;         // duration for open trading on scalar prediction markets
  uint public timeToPriceResolution; // Duration from start of prediction markets until date of final price resolution
  int public upperBound;
  int public lowerBound;
  bool public isFunded;

  FutarchyOracle public futarchyOracle;                      // Futarchy Oracle to resolve challenge
  FutarchyOracleFactory public futarchyOracleFactory;        // Factory to create FutarchyOracle
  CentralizedTimedOracleFactory public centralizedTimedOracleFactory;  // Oracle to resolve scalar prediction markets
  LMSRMarketMaker public lmsrMarketMaker;                    // MarketMaker for scalar prediction markets
  Token public token;                                        // Address of the TCR's intrinsic ERC20 token
  uint public winningMarketIndex;                            // Index of scalar prediction market with greatest average price for long token


  // ------------
  // CONSTRUCTOR:
  // ------------
  /// @dev Contructor                   Sets up majority of the FutarchyChallenge global state variables
  /// @param _tokenAddr                 Address of the TCR's intrinsic ERC20 token
  /// @param _challenger                Address of the challenger
  /// @param _listingOwner              Address of the listing owner
  /// @param _stakeAmount               Number of tokens to stake for either party during challenge
  /// @param _tradingPeriod             Duration for open trading on scalar prediction markets
  /// @param _timeToPriceResolution     Duration from start of prediction markets until date of final price resolution
  /// @param _futarchyOracleFactory     Factory to create futarchyOracle
  /// @param _centralizedTimedOracleFactory  Factory to create centralizedTimedOracle for scalar prediction markets
  /// @param _lmsrMarketMaker           LMSR Market Maker for scalar prediction markets
  function FutarchyChallenge(
    address _tokenAddr,
    address _challenger,
    address _listingOwner,
    uint _stakeAmount,
    uint _tradingPeriod,
    uint _timeToPriceResolution,
    int _upperBound,
    int _lowerBound,
    FutarchyOracleFactory _futarchyOracleFactory,
    CentralizedTimedOracleFactory _centralizedTimedOracleFactory,
    LMSRMarketMaker _lmsrMarketMaker
  ) public {
    challenger = _challenger;
    listingOwner = _listingOwner;

    token = Token(_tokenAddr);
    stakeAmount = _stakeAmount;
    tradingPeriod = _tradingPeriod;
    timeToPriceResolution = _timeToPriceResolution;
    upperBound = _upperBound;
    lowerBound = _lowerBound;
    futarchyOracleFactory = _futarchyOracleFactory;
    centralizedTimedOracleFactory = _centralizedTimedOracleFactory;
    lmsrMarketMaker = _lmsrMarketMaker;
  }

  // ------------
  // Challenge Interface:
  // ------------
  /// @dev start          Creates and funds FutarchyOracle. Futarchy Oracle will spin up
  ///                     corresponding prediction markets which will open for trade within
  ///                     60 seconds of this function invocation

  function start() public {
    require(!isStarted);

    uint resolutionDate = now + timeToPriceResolution;
    CentralizedTimedOracle _centralizedTimedOracle = centralizedTimedOracleFactory.createCentralizedTimedOracle(
      'QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG',
      resolutionDate
    );

    futarchyOracle = futarchyOracleFactory.createFutarchyOracle(
      token,
      _centralizedTimedOracle,
      2,
      lowerBound,
      upperBound,
      lmsrMarketMaker,
      0,
      tradingPeriod,
      now
    );

    isStarted = true;

    _Started(msg.sender, stakeAmount, address(futarchyOracle));
  }

  function fund() public {
    require(isStarted && !isFunded);
    require(token.transferFrom(msg.sender, this, stakeAmount));
    require(token.approve(futarchyOracle, stakeAmount));

    futarchyOracle.fund(stakeAmount);
    isFunded = true;

    _Funded(msg.sender, stakeAmount, address(futarchyOracle));
  }

  /// @dev ended  returns whether Challenge has ended
  function ended() public view returns (bool) {
    return futarchyOracle.isOutcomeSet();
  }

  /// @dev passed  returns whether Challenge has passed
  function passed() public view returns (bool) {
    require(ended());

    // marketIndex 1 == deniedScalar
    // if proposal is denied, the challenge has passed.
    return futarchyOracle.getOutcome() == 1;
  }

  function winnerRewardAmount() public view returns (uint256) {
    return stakeAmount;
  }

  function close() public {
    futarchyOracle.close();
  }

  //@dev TODO: Temporary function until we have legitimate oracle which doesn't require
  //           ownership rights to resolve oracle. For CentralizedTimedOracle, only
  //           owner (this contract) can call setOutcome.
  function setScalarOutcome(CentralizedTimedOracle _oracle, int256 _outcome) public {
    _oracle.setOutcome(_outcome);
  }
}
