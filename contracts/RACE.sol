pragma solidity ^0.6.3;
pragma experimental ABIEncoderV2;

import "./NodeRegistry.sol";
import "./PostOffice.sol";
import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
// StoragePayments pays out the money paid to the PostOffice to the nodes who earned this. 
// A node can go offline and be reasonable sure to get his money, which is safeguarded by incentivizing refutation of frivolous challenges
contract StoragePayments {
    
    // TODO. price, being the sum of two child nodes must be included in the parent node. That way, we can efficiently challenge the Price of the root node
    // TODO: what if batch doesn't have any funds anymore?
    // TODO: make cashoutRequest only possible if you are staked or are expected to have acquired enough income (based on time online (?))
    
    PostOffice postOffice;
    NodeRegistry nodeRegistry;
    
    // use OpenZeppelin MerkleProof library to process merkle proofs
    using MerkleProof for bytes32[];
    
    /** 
      omissionChallengeStake is the amount of money, needed to challenge a payout request. 
      earned back fully + a profit (from income/stake of requestor) by succesfully challenging 
      earned partly by a refutor by succesfully refuting the challenge
      TODO: make this somehow modifyable
    */
    uint256 omissionChallengeStake;
    
    // Invoice is a claim to earn price per block money from batchID for the period of startBlock to endBlock
    struct Invoice {
        bytes32 batchID; // batch identifier. Should not have received an update (price change) during period
        uint256 startBlock; // starting block of period
        uint256 endBlock; // ending block of period
        uint256 price; // proposed price. Should be lower than the maximumPrice of requestor during period and higher than batch minimumPrize during period
    }
    
    // OmissionChallenge is the information, needed to challenge an omission
    struct OmissionChallenge {
        Invoice invoice;
        uint256 when; // set to the current block number upon challenging, back to 0 after succesfully refuting
    }
    
    // PendingPayments is the information, needed to process a pending payment
    struct PendingPayments {
        uint256 when; // block number when payment was requested. Updated upon challenge and set back to original after succesfully refuting
        uint256 amount; // how much money is requested
        bytes32 proof; // root node of merkle tree, which stores the calculation to amount
        bool paid; // true when paid out. Paid out PendingPayments can't be challenged anymore
        mapping(address => OmissionChallenge[]) omissionChallengeRegistry; // one address may make multiple challenges
    }
    
    // here, we register the PendingPayments. A node can have one pending pament at a time.
    mapping(address => PendingPayments) pendingPaymentsRegistry;
    
    constructor(uint256 _omissionChallengeStake, address _postOffice, address _nodeRegistry) public {
        omissionChallengeStake = _omissionChallengeStake;
        postOffice = PostOffice(_postOffice);
        nodeRegistry = NodeRegistry(_nodeRegistry);
    }
    
    // function proposes to do a payment by creating a PendingPayments entry for msg.sender
    // make sure only one pending payment can exist at a time 
    function proposePayment(uint256 payment, bytes32 root) public {
        // only allow payments by nodes who have been online for some time or are staked. 
    }
    
    // we require that invoices are complete and correct. This challenge challenges completeness by uploading a Invoice that was not in the tree, submitted by requestor. 
    // challengeComplete can be refuted by proofing that uploaded Invoice is incorrect. 
    // challengee needs to pay OmissionChallenge money to start challenge, but can earn this amount back + a profit when succesfull
    // a claim is perceived succesfull when no refutation is received with a certain period. TODO
    function challengeComplete(address requestor, bytes32[] memory proofL, bytes32 leafL, bytes32[] memory proofR, bytes32 leafR, bytes32 root, Invoice memory invoice) public payable {
        require(!pendingPaymentsRegistry[requestor].paid);
        require(proofL.verify(root, leafL)); 
        require(proofR.verify(root, leafR)); 
        require(msg.value == omissionChallengeStake);
        bytes32 leafM = toLeaf(invoice);
        require(leafL < leafM && leafM < leafR);
        // update when
        pendingPaymentsRegistry[requestor].when = now;
        pendingPaymentsRegistry[requestor].omissionChallengeRegistry[msg.sender].push(OmissionChallenge(invoice, now));
    }
    
    function challengeIncorrect() public {
        //TODO. In order to challenge an incorrect entry, a node may submit himself the Invoice (if known). It might also be unclear what the invoice was (e.g. it is complete nonsense or the requestor did something weird).
        // in this case, we need to first request the Invoice. Invoice may be submitted by anybody who knows the invoice.
    }
    
    function challengeAmount() public {
        // TODO. Leaf nodes amount don't add up to root amount. Need to adjust merkle structure, to include amount in in-between nodes
    }
    
    // supposedly non-included invoice was not correct due to no price match
    function refuteCompleteNoMatch(address requestor, address challengee, uint256 refuteIndex, uint256 batchIndex, uint256 nodeRegistryIndex) public {
         // should not have paid out yet
        require(!pendingPaymentsRegistry[requestor].paid);
        // if when == 0, challenge is already refuted
        require(pendingPaymentsRegistry[requestor].omissionChallengeRegistry[challengee][refuteIndex].when != 0);
        require(!isPriceMatch(requestor, nodeRegistryIndex, refuteIndex, batchIndex));
        // make challenge refuted, by setting when to 0
        pendingPaymentsRegistry[requestor].omissionChallengeRegistry[challengee][refuteIndex].when = 0;
        // transfer part of omissionChallengeStake. Other part is "burned"
        msg.sender.transfer(omissionChallengeStake/2);
        // TODO update when on PendingPayments, so cashout can happen automatically
    }
    
    // supposedly non-included invoice was not correct due to cheaper nodes available
    function refuteCompleteCheaperNodes() public {
        //TODO
    }
    
    // supposedly non-included invoice was not correct due to batch out of balance
    function refuteCompleteEmptyBalance() public {
        //TODO
    }
    
    function refuteIncorrectNoMatch() public {
        //TODO. Opposite logic of refuteCompleteNoMatch
    }
    
    function refuteIncorrectCheaperNodes() public {
        // TODO: opposit logic of refuteCompleteCheaperNodes
    }
    
    function refuteIncorrectEmptyBalance() public {
        //TODO: opposite logic of refuteCompleteEmptyBalance
    }
    function requestLeafNode() public {
        //TODO: challenger suspects a faulty leaf node, or doesn't know what information hashes to the leaf node. This is refuted by uploading a Invoice, which data can be refuted
    }
    
    function isPriceMatch(address requestor, uint256 nodeRegistryIndex, uint256 refuteIndex, uint256 batchIndex) public view returns(bool) {
        (uint256 blockheightNR, uint256 minimumPrizeNR) = getNodeRegistry(requestor, nodeRegistryIndex);
        (uint256 blockheightNROne, ) = getNodeRegistry(requestor, nodeRegistryIndex + 1);
        (uint256 blockheightBatch, , uint256 maximumPriceBatch) = getBatch(pendingPaymentsRegistry[requestor].omissionChallengeRegistry[msg.sender][refuteIndex].invoice.batchID, batchIndex);
        // return false directly if the blockheight of the batch is outside of the blockheight of the node registry
        if(!(blockheightBatch >= blockheightNR && blockheightBatch <= blockheightNROne)) {
            return false;
        }
        return minimumPrizeNR <= maximumPriceBatch;
    }

    function getBatch(bytes32 batchID, uint256 index) public view returns(uint256 blockHeight, uint256 depth, uint256 maximumPrice) {
        return postOffice.batchRegistry(batchID, index);
    }

    function getNodeRegistry(address node, uint256 index) public view returns(uint256, uint256) {
        nodeRegistry.nodeRegistry(node, index);
    }

    function requestInvoice(bytes32[] memory proof, bytes32 root, bytes32 proofLeaf) public {

    }

    function pay() public {
        //TODO
    }

    function cancel() public {
        //TODO
    }

    function toLeaf(Invoice memory invoice) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(invoice.batchID, invoice.startBlock, invoice.endBlock, invoice.price));
    }
}