pragma solidity ^0.6.4;


contract kyc {
    address public admin;
    uint256 constant MIN_BANKS_FOR_AUTHENTICITY_CHECKS = 5;

    // The Sender Address which initializes the contract is the Admin
    constructor() public {
        admin = msg.sender;
    }

    /*Struct customer
	uname: username of the customer
	data: customer data
	rating: rating given to customer given based on regularity
	upvotes: number of upvotes received from banks
	bank: address of bank that validated the customer account

	*/
    struct Customer {
        string username;
        string data;
        // uint upvotes;
        bool exists;
        // string password;
        bool kycStatus;
        uint256 upvotes;
        uint256 downVotes;
        address bank;
    }

    /*  Struct Bank
	name: name of the Bank
	ethAddress: address of the Bank
	regNumber: registration number for the bank.*/

    struct Bank {
        string name;
        address ethAddress;
        uint256 report;
        uint256 kycCount;
        bool kycPermission;
        string regNumber;
        bool exists;
    }

    struct Request {
        string username;
        address bankAddress;
        string customerData;
    }

    // Customer List (Customer Name => Customer Data)
    mapping(string => Customer) public customerlist;

    // Request List (customer username => mutiple requests added for the same customer)
    mapping(string => Request[]) public requestList;

    // Bank List (Address of Bank => Bank Data)
    mapping(address => Bank) public bankList;

    // To keep track the total no of Banks Added
    uint256 private totalBanks;

    // Modifier to allow only admin execute a specific functionality
    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    // Functionalities of Admin

    function addBank(
        string memory name,
        address ethAddress,
        string memory regNumber
    ) public payable onlyAdmin {
        bankList[ethAddress] = Bank(
            name,
            ethAddress,
            0,
            0,
            true,
            regNumber,
            true
        );
        totalBanks++;
    }

    function modifyKycPermission(address ethAddress) public payable onlyAdmin {
        bankList[ethAddress].kycPermission = corruptCheck(ethAddress);
    }

    function removeBank(address ethAddress) public payable onlyAdmin {
        delete (bankList[ethAddress]);
        totalBanks--;
    }

    // Functionalities of Banks

    function addKYCRequest(string memory username, string memory data)
        public
        payable
    {
        // check if customer exists
        // If kycPermission is set to false bank won’t be allowed to add requests for any customer.
        if (
            !customerlist[username].exists ||
            !bankList[msg.sender].kycPermission
        ) return;
        // increase the kyCount by 1 for bank initiating the requestList
        bankList[msg.sender].kycCount += 1;
        // add the kyc Request to requestList

        requestList[username].push(Request(username, msg.sender, data));
    }

    function removeKYCRequest(string memory username)
        public
        payable
        returns (uint256)
    {
        if (!bankList[msg.sender].kycPermission) {
            delete (requestList[username]);
            return 0;
        }
        return 1;
    }

    function upvoteCustomer(string memory username) public payable {
        if (bankList[msg.sender].exists && bankList[msg.sender].kycPermission) {
            customerlist[username].upvotes++;
        }
    }

    function downvoteCustomer(string memory username) public payable {
        if (bankList[msg.sender].exists && bankList[msg.sender].kycPermission) {
            customerlist[username].downVotes > 0
                ? customerlist[username].downVotes--
                : 0;
        }
    }

    function getBankReports(address ethAddress) public view returns (uint256) {
        if (bankList[msg.sender].exists) {
            return bankList[ethAddress].report;
        }
        return 0;
    }

    function getCustomerStatus(string memory username)
        public
        view
        returns (bool)
    {
        if (bankList[msg.sender].exists) {
            return customerlist[username].kycStatus;
        }
        return false;
    }

    function getBankDetails(address ethAddress)
        public
        payable
        returns (string memory, uint256, uint256, bool, string memory)
    {
        if (bankList[msg.sender].exists) {
            return (
                bankList[ethAddress].name,
                bankList[ethAddress].report,
                bankList[ethAddress].kycCount,
                bankList[ethAddress].kycPermission,
                bankList[ethAddress].regNumber
            );
        }
    }

    function addCustomer(string memory username, string memory data)
        public
        payable
        returns (uint256)
    {
        // Check if Bank Exists
        if (!bankList[msg.sender].exists) {
            return 1;
        }
        // check if customer exist
        if (!customerlist[username].exists) {
            customerlist[username] = Customer(
                username,
                data,
                true,
                false,
                0,
                0,
                msg.sender
            );
            // Once customer is added, verify the downVotes and upvotes to decide on the kycStatus
            updateCustomerKYCStatus(username);
            return 0;
        }
        return 1;
    }

    function removeCustomer(string memory username)
        public
        payable
        returns (int256)
    {
        if (bankList[msg.sender].exists) {
            if (customerlist[username].exists) {
                delete (customerlist[username]);
                if (requestList[username].length > 0) {
                    delete (requestList[username]);
                }
                return 0;
            }
        }
        return 1;
    }

    function modifyCustomer(string memory username, string memory data)
        public
        payable
        returns (uint256)
    {
        if (!bankList[msg.sender].exists) {
            if (customerlist[username].exists) {
                customerlist[username].data = data;
                customerlist[username].upvotes = 0;
                customerlist[username].downVotes = 0;
                return 0;
            }
        }
        return 1;
    }

    function viewCustomer(string memory username)
        public
        payable
        returns (string memory)
    {
        if (bankList[msg.sender].exists && customerlist[username].exists) {
            return customerlist[username].data;
        }
        return "Customer does not exist";
    }

    function updateCustomerKYCStatus(string memory uname) public payable {
        if (customerlist[uname].upvotes > customerlist[uname].downVotes) {
            if (totalBanks > MIN_BANKS_FOR_AUTHENTICITY_CHECKS) {
                if (customerlist[uname].downVotes > (totalBanks / 3)) {
                    customerlist[uname].kycStatus = false;
                } else {
                    customerlist[uname].kycStatus = true;
                }
            }
        }
        customerlist[uname].kycStatus = false;
    }

    function corruptCheck(address ethAddress) private view returns (bool) {
        if (totalBanks > MIN_BANKS_FOR_AUTHENTICITY_CHECKS) {
            if (bankList[ethAddress].report > (totalBanks / 3)) {
                return false;
            }
        }
        return true;
    }

    // Utility Functions
    function compareStrings(string memory a, string memory b)
        public
        pure
        returns (bool)
    {
        return (keccak256(abi.encodePacked((a))) ==
            keccak256(abi.encodePacked((b))));
    }
}
