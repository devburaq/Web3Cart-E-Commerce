// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/*
                                                                                             
                                                                         
MMMMMMMM               MMMMMMMMBBBBBBBBBBBBBBBBB        OOOOOOOOO     
M:::::::M             M:::::::MB::::::::::::::::B     OO:::::::::OO   
M::::::::M           M::::::::MB::::::BBBBBB:::::B  OO:::::::::::::OO 
M:::::::::M         M:::::::::MBB:::::B     B:::::BO:::::::OOO:::::::O
M::::::::::M       M::::::::::M  B::::B     B:::::BO::::::O   O::::::O
M:::::::::::M     M:::::::::::M  B::::B     B:::::BO:::::O     O:::::O
M:::::::M::::M   M::::M:::::::M  B::::BBBBBB:::::B O:::::O     O:::::O
M::::::M M::::M M::::M M::::::M  B:::::::::::::BB  O:::::O     O:::::O
M::::::M  M::::M::::M  M::::::M  B::::BBBBBB:::::B O:::::O     O:::::O
M::::::M   M:::::::M   M::::::M  B::::B     B:::::BO:::::O     O:::::O
M::::::M    M:::::M    M::::::M  B::::B     B:::::BO:::::O     O:::::O
M::::::M     MMMMM     M::::::M  B::::B     B:::::BO::::::O   O::::::O
M::::::M               M::::::MBB:::::BBBBBB::::::BO:::::::OOO:::::::O
M::::::M               M::::::MB:::::::::::::::::B  OO:::::::::::::OO 
MMMMMMMM               MMMMMMMMBBBBBBBBBBBBBBBBB        OOOOOOOOO     
                                        
 
                                                                                                     
 
                                                                                                 
x.com/devburaq
*/

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

/**
 * @title XPayr v3.5 Ultra Lite
 * @author devburaq
 * @notice Size optimized for Spurious Dragon limit. Removed non-critical events.
 */
contract XPayr is Initializable, UUPSUpgradeable, AccessControlUpgradeable, PausableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20MetadataUpgradeable;

    // --- CUSTOM ERRORS ---
    // Registration
    error AlreadyRegistered();
    error InvalidAdminAddress();
    error NotRegistered();
    error NoMarketplaceAdmin();

    // Purchases
    error BuyerBlacklisted();
    error InvalidCartLength();
    error ChainInactive();
    error InsufficientPayment();
    error RefundFailed();
    error TokenNotSupported();
    error InsufficientAllowance();
    error InvalidSeller();
    error SellerNotRegistered();
    error SellerBlacklisted();
    error FeesExceedTotal();
    error SellerPaymentFailed();
    error AdminPaymentFailed();

    // Rewards
    error NoRewards();
    error BelowMinimumClaim();
    error NativeTransferFailed();

    // Plans & Subscriptions
    error InvalidPlanId();
    error PlanInactive();
    error AlreadySubscribedToPlatform();
    error PlanIdReserved();
    error PlanAlreadyExists();
    error InvalidTokenAddress();
    error RateTooHigh();
    error CommissionTooHigh();
    error PlanNotFound();
    error PlatformPlanNotFound();
    error InvalidLicenseKey();
    error LicenseKeyAlreadyUsed();

    // Config
    error FeeTooHigh();
    error NoXPayrWallet();
    error InvalidWalletAddress();
    error InvalidWalletIndex();

    // Security
    error NoBalance();
    error EmergencyWithdrawFailed();

    // --- ROLES ---
    bytes32 public constant CONFIG_MANAGER_ROLE = keccak256("CONFIG_MANAGER_ROLE");
    bytes32 public constant SECURITY_ROLE = keccak256("SECURITY_ROLE");

    // --- STRUCTS ---
    struct NetworkConfig {
        uint256 nativeTransferGasLimit;
        bool isActive;
    }

    struct CartItem {
        address payable seller;
        uint256 productId;
        bytes32 sku;
        uint256 price;
        uint256 quantity;
        uint256 fixedDiscount;
        uint16 discountRateBps;
        uint256 fixedTax;
        uint16 taxRateBps;
    }

    struct SubscriptionPlan {
        string name;
        address paymentToken;
        uint256 price;
        uint256 commissionRateBps;
        uint32 durationDays;
        uint32 productLimit;
        bool isActive;
    }

    struct VendorSubscription {
        uint8 planId;
        uint256 expiresAt;
    }

    struct PlatformPlan {
        string name;
        address paymentToken;
        uint256 licenseFee;
        uint256 commissionBps;
        bool isActive;
    }

    struct AdminSubscription {
        uint8 planId;
        bool isActive;
    }

    struct BatchPlanInput {
        uint8 planId;
        string name;
        address token;
        uint256 price;
        uint256 rateBps;
        uint32 duration;
        uint32 limit;
    }

    struct BatchPlatformPlanInput {
        uint8 planId;
        string name;
        address token;
        uint256 fee;
        uint256 commissionBps;
    }

    // --- STATE VARIABLES ---
    address payable[] public xPayrWallets;
    
    uint256 public walletIndex;
    uint256 private _deprecated_contractFee; 
    uint256 public defaultCommissionRateBps;

    // Vendor plans
    mapping(uint8 => SubscriptionPlan) public subscriptionPlans;
    uint8[] public activePlanIds;
    mapping(address => VendorSubscription) public vendorSubscriptions;

    // Platform plans & admin state
    mapping(uint8 => PlatformPlan) public platformPlans;
    mapping(address => AdminSubscription) public adminSubscriptions;
    mapping(address => uint256) public xpayrFeeBps;
    mapping(address => address payable) public marketplaceAdminOf;

    // Core
    mapping(uint256 => NetworkConfig) public networkConfigs;
    mapping(address => bool) public registeredUsers;
    mapping(address => bool) public blacklisted;
    mapping(address => bool) public supportedTokens;
    mapping(address => string) public tokenTypes;

    // Analytics & referral
    uint256 public totalCollectedNative;
    uint256 public totalCollectedUsdc;
    uint256 public totalCollectedUsdt;
    mapping(address => mapping(address => uint256)) public userPayments;
    
    address public xpayrTokenAddress;
    mapping(address => address) public userToReferrer;
    mapping(address => mapping(address => uint256)) public claimableRewards;
    uint256 public referralRewardRate;
    
    mapping(address => uint256) public minClaimAmounts;

    mapping(bytes32 => bool) public usedLicenseKeys;

    // --- EVENTS ---
    // Minimal set of events to ensure deployability
    event NewPurchase(address indexed buyer, uint256 totalAmount, uint256 timestamp, address token);
    event ReferralRewardClaimed(address indexed referrer, address indexed token, uint256 amount);
    event Subscribed(address indexed vendor, uint8 indexed planId, uint256 expiresAt);
    
    event AdminSubscribed(
        address indexed admin, 
        uint8 indexed planId, 
        bytes32 indexed licenseKey
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // -------------------------
    // INITIALIZER
    // -------------------------
    function initialize(
        address _initialAdmin,
        address payable _initialXPayrWallet,
        uint256 _initialContractFee,
        uint256 _initialReferralRate,
        uint256 _defaultCommissionRateBps
    ) public initializer {
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _initialAdmin);
        _grantRole(CONFIG_MANAGER_ROLE, _initialAdmin);
        _grantRole(SECURITY_ROLE, _initialAdmin);

        xPayrWallets.push(_initialXPayrWallet);
        _deprecated_contractFee = _initialContractFee;
        referralRewardRate = _initialReferralRate;
        defaultCommissionRateBps = _defaultCommissionRateBps;

        // Register Super Admin
        marketplaceAdminOf[_initialAdmin] = payable(_initialAdmin);
        adminSubscriptions[_initialAdmin] = AdminSubscription({ planId: 0, isActive: true });
        xpayrFeeBps[_initialAdmin] = 0;
    }

    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    // -------------------------
    // USER REGISTRATION
    // -------------------------
    function registerUser(address _referrer) external {
        _registerUserInternal(msg.sender, _referrer, payable(msg.sender));
    }

    function registerUser(address _referrer, address payable _marketplaceAdmin) external {
        if (_marketplaceAdmin == address(0)) revert InvalidAdminAddress();
        _registerUserInternal(msg.sender, _referrer, _marketplaceAdmin);
    }

    function adminRegisterUser(
        address _user, 
        address _referrer, 
        address payable _marketplaceAdmin
    ) external onlyRole(CONFIG_MANAGER_ROLE) {
        if (_user == address(0)) revert InvalidWalletAddress();
        if (_marketplaceAdmin == address(0)) revert InvalidAdminAddress();
        _registerUserInternal(_user, _referrer, _marketplaceAdmin);
    }

    function adminBatchRegisterUsers(
        address[] calldata _users, 
        address[] calldata _referrers, 
        address payable[] calldata _marketplaceAdmins
    ) external onlyRole(CONFIG_MANAGER_ROLE) {
        if (_users.length != _referrers.length || _users.length != _marketplaceAdmins.length) revert InvalidCartLength();
        
        for (uint256 i = 0; i < _users.length;) {
            if (_users[i] == address(0)) {
                unchecked { ++i; }
                continue;
            }
            if (_marketplaceAdmins[i] == address(0)) {
                unchecked { ++i; }
                continue;
            }
            
            if (registeredUsers[_users[i]]) {
                unchecked { ++i; }
                continue;
            }

            _registerUserInternal(_users[i], _referrers[i], _marketplaceAdmins[i]);
            unchecked { ++i; }
        }
    }

    function _registerUserInternal(address _user, address _referrer, address payable _marketplaceAdmin) private {
        if (registeredUsers[_user]) revert AlreadyRegistered();
        registeredUsers[_user] = true;
        marketplaceAdminOf[_user] = _marketplaceAdmin;

        if (_referrer != address(0) && _referrer != _user && registeredUsers[_referrer]) {
            userToReferrer[_user] = _referrer;
        }
        // Removed UserRegistered event to save size
    }

    // -------------------------
    // PURCHASES (MODEL A)
    // -------------------------
    function purchase(CartItem[] memory cartItems) external payable nonReentrant whenNotPaused {
        if (blacklisted[msg.sender]) revert BuyerBlacklisted();
        if (cartItems.length == 0 || cartItems.length > 50) revert InvalidCartLength();
        if (!networkConfigs[block.chainid].isActive) revert ChainInactive();

        uint256 grandTotal = _validateCartAndCalculateTotal(cartItems);
        if (msg.value < grandTotal) revert InsufficientPayment();

        userPayments[msg.sender][address(0)] += grandTotal;
        totalCollectedNative += grandTotal;

        _distributeMarketplacePayment(cartItems, grandTotal);

        uint256 excess = msg.value - grandTotal;
        if (excess > 0) {
            (bool success, ) = msg.sender.call{value: excess}("");
            if (!success) revert RefundFailed();
        }

        emit NewPurchase(msg.sender, grandTotal, block.timestamp, address(0));
    }

    function purchaseWithToken(CartItem[] memory cartItems, address tokenAddress) external nonReentrant whenNotPaused {
        if (blacklisted[msg.sender]) revert BuyerBlacklisted();
        if (cartItems.length == 0 || cartItems.length > 50) revert InvalidCartLength();
        if (!networkConfigs[block.chainid].isActive) revert ChainInactive();
        if (!supportedTokens[tokenAddress]) revert TokenNotSupported();
        IERC20MetadataUpgradeable token = IERC20MetadataUpgradeable(tokenAddress);
        uint256 grandTotal = _validateCartAndCalculateTotal(cartItems);

        if (token.allowance(msg.sender, address(this)) < grandTotal) revert InsufficientAllowance();

        token.safeTransferFrom(msg.sender, address(this), grandTotal);
        userPayments[msg.sender][tokenAddress] += grandTotal;

        string memory tType = tokenTypes[tokenAddress];
        
        uint8 decimals = token.decimals();
        uint256 normalizedAmount = grandTotal;
        
        if (decimals < 18) {
            normalizedAmount = grandTotal * (10**(18 - decimals));
        } else if (decimals > 18) {
            normalizedAmount = grandTotal / (10**(decimals - 18));
        }

        if (keccak256(bytes(tType)) == keccak256(bytes("USDC"))) totalCollectedUsdc += normalizedAmount;
        else if (keccak256(bytes(tType)) == keccak256(bytes("USDT"))) totalCollectedUsdt += normalizedAmount;

        _distributeMarketplaceTokenPayment(cartItems, token, grandTotal);
        emit NewPurchase(msg.sender, grandTotal, block.timestamp, tokenAddress);
    }

    // -------------------------
    // CLAIM REWARDS
    // -------------------------
    function claimReferralRewards(address _token) external nonReentrant {
        uint256 amount = claimableRewards[msg.sender][_token];
        if (amount == 0) revert NoRewards();
        if (amount < minClaimAmounts[_token]) revert BelowMinimumClaim();

        claimableRewards[msg.sender][_token] = 0;
        if (_token == address(0)) {
            (bool sent, ) = msg.sender.call{value: amount}("");
            if (!sent) revert NativeTransferFailed();
        } else {
            IERC20MetadataUpgradeable(_token).safeTransfer(msg.sender, amount);
        }
        emit ReferralRewardClaimed(msg.sender, _token, amount);
    }

    // -------------------------
    // SUBSCRIPTIONS & PLANS
    // -------------------------
    function subscribeToPlan(uint8 _planId) external nonReentrant whenNotPaused {
        if (!registeredUsers[msg.sender]) revert NotRegistered();
        if (_planId == 0) revert InvalidPlanId();
        
        SubscriptionPlan storage plan = subscriptionPlans[_planId];
        if (!plan.isActive) revert PlanInactive();

        address payable adminWallet = marketplaceAdminOf[msg.sender];
        if (adminWallet == address(0)) revert NoMarketplaceAdmin();

        if (plan.price > 0) {
            IERC20MetadataUpgradeable(plan.paymentToken).safeTransferFrom(msg.sender, address(this), plan.price);
            IERC20MetadataUpgradeable(plan.paymentToken).safeTransfer(adminWallet, plan.price);
        }

        uint256 expiresAt = vendorSubscriptions[msg.sender].expiresAt;
        uint256 newExpiresAt = (expiresAt > block.timestamp ? expiresAt : block.timestamp) + (plan.durationDays * 1 days);

        vendorSubscriptions[msg.sender] = VendorSubscription(_planId, newExpiresAt);
        emit Subscribed(msg.sender, _planId, newExpiresAt);
    }

    function purchasePlatformPlan(
        uint8 _planId,
        bytes32 _licenseKey
    ) external nonReentrant whenNotPaused {
        PlatformPlan storage plan = platformPlans[_planId];
        if (!plan.isActive || _planId == 0) revert InvalidPlanId();
        if (adminSubscriptions[msg.sender].planId != 0) revert AlreadySubscribedToPlatform();
        if (xPayrWallets.length == 0) revert NoXPayrWallet();
        
        if (_licenseKey == bytes32(0)) revert InvalidLicenseKey();
        if (usedLicenseKeys[_licenseKey]) revert LicenseKeyAlreadyUsed();
        usedLicenseKeys[_licenseKey] = true;

        if (plan.licenseFee > 0) {
            IERC20MetadataUpgradeable(plan.paymentToken).safeTransferFrom(msg.sender, address(this), plan.licenseFee);
            address payable target = xPayrWallets[walletIndex % xPayrWallets.length];
            IERC20MetadataUpgradeable(plan.paymentToken).safeTransfer(target, plan.licenseFee);
            walletIndex++;
        }

        adminSubscriptions[msg.sender] = AdminSubscription(_planId, true);
        marketplaceAdminOf[msg.sender] = payable(msg.sender);
        xpayrFeeBps[msg.sender] = plan.commissionBps;
        emit AdminSubscribed(msg.sender, _planId, _licenseKey);
    }

    // -------------------------
    // MANAGEMENT / CONFIG
    // -------------------------
    function configureNetwork(uint256 _chainId, uint256 _gasLimit, bool _isActive) external onlyRole(CONFIG_MANAGER_ROLE) {
        networkConfigs[_chainId] = NetworkConfig({ nativeTransferGasLimit: _gasLimit, isActive: _isActive });
    }

    function setXpayrFee(address _admin, uint256 _feeBps) external onlyRole(CONFIG_MANAGER_ROLE) {
        if (_admin == address(0)) revert InvalidAdminAddress();
        if (_feeBps > 100000) revert FeeTooHigh();
        
        xpayrFeeBps[_admin] = _feeBps;
    }

    function setReferralRewardRate(uint256 _rate) external onlyRole(CONFIG_MANAGER_ROLE) {
        if (_rate > 100) revert RateTooHigh();
        referralRewardRate = _rate;
    }

    function addXPayrWallet(address payable _wallet) external onlyRole(CONFIG_MANAGER_ROLE) {
        if (_wallet == address(0)) revert InvalidWalletAddress();
        xPayrWallets.push(_wallet);
    }

    function removeXPayrWallet(uint256 _index) external onlyRole(CONFIG_MANAGER_ROLE) {
        if (_index >= xPayrWallets.length) revert InvalidWalletIndex();
        xPayrWallets[_index] = xPayrWallets[xPayrWallets.length - 1];
        xPayrWallets.pop();
    }

    function setTokenSupport(address _token, bool _supported, string memory _type) external onlyRole(CONFIG_MANAGER_ROLE) {
        supportedTokens[_token] = _supported;
        tokenTypes[_token] = _type;
    }

    function setXpayrTokenAddress(address _token) external onlyRole(CONFIG_MANAGER_ROLE) {
        xpayrTokenAddress = _token;
    }

    function setMinClaimAmount(address _token, uint256 _amount) external onlyRole(CONFIG_MANAGER_ROLE) {
        minClaimAmounts[_token] = _amount;
    }

    function setDefaultCommissionRateBps(uint256 _rate) external onlyRole(CONFIG_MANAGER_ROLE) {
        if (_rate > 100000) revert RateTooHigh();
        defaultCommissionRateBps = _rate;
    }

    // --- Vendor plan mgmt ---
    function addPlan(uint8 _planId, string memory _name, address _token, uint256 _price, uint256 _rateBps, uint32 _days, uint32 _limit) external onlyRole(CONFIG_MANAGER_ROLE) {
        if (_planId == 0) revert PlanIdReserved();
        if (subscriptionPlans[_planId].durationDays != 0) revert PlanAlreadyExists();
        if (_token == address(0)) revert InvalidTokenAddress();
        if (_rateBps > 100000) revert RateTooHigh();
        subscriptionPlans[_planId] = SubscriptionPlan(_name, _token, _price, _rateBps, _days, _limit, true);
        activePlanIds.push(_planId);
    }

    function batchAddSubscriptionPlans(BatchPlanInput[] calldata _plans) external onlyRole(CONFIG_MANAGER_ROLE) {
        for (uint256 i = 0; i < _plans.length;) {
            BatchPlanInput calldata p = _plans[i];

            if (p.planId == 0) revert PlanIdReserved();
            if (p.token == address(0)) revert InvalidTokenAddress();
            if (p.rateBps > 100000) revert RateTooHigh();

            if (subscriptionPlans[p.planId].durationDays == 0) {
                activePlanIds.push(p.planId);
            }

            subscriptionPlans[p.planId] = SubscriptionPlan({
                name: p.name,
                paymentToken: p.token,
                price: p.price,
                commissionRateBps: p.rateBps,
                durationDays: p.duration,
                productLimit: p.limit,
                isActive: true
            });

            unchecked { ++i; }
        }
    }

    function updatePlan(uint8 _planId, string memory _name, address _token, uint256 _price, uint32 _days, uint32 _limit) external onlyRole(CONFIG_MANAGER_ROLE) {
        SubscriptionPlan storage p = subscriptionPlans[_planId];
        if (p.durationDays == 0) revert PlanNotFound();
        if (_token == address(0)) revert InvalidTokenAddress();
        
        p.name = _name;
        p.paymentToken = _token;
        p.price = _price;
        p.durationDays = _days;
        p.productLimit = _limit;
    }

    function updatePlanCommission(uint8 _planId, uint256 _rateBps) external onlyRole(CONFIG_MANAGER_ROLE) {
        SubscriptionPlan storage p = subscriptionPlans[_planId];
        if (p.durationDays == 0) revert PlanNotFound();
        if (_rateBps > 100000) revert RateTooHigh();
        
        p.commissionRateBps = _rateBps;
    }

    function setPlanStatus(uint8 _planId, bool _active) external onlyRole(CONFIG_MANAGER_ROLE) {
        if (subscriptionPlans[_planId].durationDays == 0) revert PlanNotFound();
        if (subscriptionPlans[_planId].isActive == _active) return;
        
        subscriptionPlans[_planId].isActive = _active;
        if (!_active) {
            for (uint i = 0; i < activePlanIds.length;) {
                if (activePlanIds[i] == _planId) {
                    activePlanIds[i] = activePlanIds[activePlanIds.length - 1];
                    activePlanIds.pop();
                    break;
                }
                unchecked { ++i; }
            }
        } else {
            activePlanIds.push(_planId);
        }
    }

    // --- Platform plan mgmt ---
    function addPlatformPlan(uint8 _planId, string memory _name, address _token, uint256 _fee, uint256 _commissionBps) external onlyRole(CONFIG_MANAGER_ROLE) {
        if (_planId == 0) revert PlanIdReserved();
        if (platformPlans[_planId].paymentToken != address(0)) revert PlanAlreadyExists();
        if (_token == address(0)) revert InvalidTokenAddress();
        if (_commissionBps > 100000) revert CommissionTooHigh();
        platformPlans[_planId] = PlatformPlan(_name, _token, _fee, _commissionBps, true);
    }

    function batchAddPlatformPlans(BatchPlatformPlanInput[] calldata _plans) external onlyRole(CONFIG_MANAGER_ROLE) {
        for (uint256 i = 0; i < _plans.length;) {
            BatchPlatformPlanInput calldata p = _plans[i];
            
            if (p.planId == 0) revert PlanIdReserved();
            if (p.token == address(0)) revert InvalidTokenAddress();
            if (p.commissionBps > 100000) revert CommissionTooHigh();

            platformPlans[p.planId] = PlatformPlan({
                name: p.name,
                paymentToken: p.token,
                licenseFee: p.fee,
                commissionBps: p.commissionBps,
                isActive: true
            });

            unchecked { ++i; }
        }
    }

    function updatePlatformPlan(uint8 _planId, string memory _name, address _token, uint256 _fee, uint256 _commissionBps) external onlyRole(CONFIG_MANAGER_ROLE) {
        if (platformPlans[_planId].paymentToken == address(0)) revert PlatformPlanNotFound();
        if (_token == address(0)) revert InvalidTokenAddress();
        if (_commissionBps > 100000) revert CommissionTooHigh();
        
        platformPlans[_planId].name = _name;
        platformPlans[_planId].paymentToken = _token;
        platformPlans[_planId].licenseFee = _fee;
        platformPlans[_planId].commissionBps = _commissionBps;
    }

    function setPlatformPlanStatus(uint8 _planId, bool _active) external onlyRole(CONFIG_MANAGER_ROLE) {
        if (platformPlans[_planId].paymentToken == address(0)) revert PlatformPlanNotFound();
        platformPlans[_planId].isActive = _active;
    }

    // -------------------------
    // SECURITY
    // -------------------------
    function pause() external onlyRole(SECURITY_ROLE) {
        _pause();
    }
    function unpause() external onlyRole(SECURITY_ROLE) {
        _unpause();
    }
    function setBlacklist(address user, bool status) external onlyRole(SECURITY_ROLE) {
        blacklisted[user] = status;
    }
    function batchSetBlacklist(address[] memory users, bool status) external onlyRole(SECURITY_ROLE) {
        for (uint i = 0; i < users.length;) {
            if (users[i] != address(0)) {
                blacklisted[users[i]] = status;
            }
            unchecked { ++i; }
        }
    }

    function emergencyWithdraw() external nonReentrant whenPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoBalance();
        if (xPayrWallets.length == 0) revert NoXPayrWallet();
        
        address payable target = xPayrWallets[walletIndex % xPayrWallets.length];
        (bool success, ) = target.call{value: balance}("");
        if (!success) revert EmergencyWithdrawFailed();
        
        walletIndex++;
    }

    function emergencyWithdrawToken(address _token) external nonReentrant whenPaused onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = IERC20MetadataUpgradeable(_token).balanceOf(address(this));
        if (balance == 0) revert NoBalance();
        if (xPayrWallets.length == 0) revert NoXPayrWallet();
        
        address payable target = xPayrWallets[walletIndex % xPayrWallets.length];
        IERC20MetadataUpgradeable(_token).safeTransfer(target, balance);
        walletIndex++;
    }

    // -------------------------
    // INTERNAL HELPERS
    // -------------------------
    function _calculateLineTotal(CartItem memory item) internal pure returns (uint256) {
        uint256 linePrice = item.price * item.quantity;
        uint256 discount = item.fixedDiscount + (linePrice * item.discountRateBps) / 10000;
        if (discount > linePrice) discount = linePrice;
        uint256 afterDiscount = linePrice - discount;
        uint256 tax = item.fixedTax + (afterDiscount * item.taxRateBps) / 10000;
        return afterDiscount + tax;
    }

    function _validateCartAndCalculateTotal(CartItem[] memory cartItems) internal view returns (uint256) {
        uint256 total = 0;
        for (uint i = 0; i < cartItems.length;) {
            CartItem memory item = cartItems[i];
            if (item.seller == address(0)) revert InvalidSeller();
            if (!registeredUsers[item.seller]) revert SellerNotRegistered();
            if (blacklisted[item.seller]) revert SellerBlacklisted();
            if (marketplaceAdminOf[item.seller] == address(0)) revert NoMarketplaceAdmin();
            total += _calculateLineTotal(item);
            unchecked { ++i; }
        }
        return total;
    }

    function _calculateReferralReward(uint256 _commission) private view returns (uint256) {
        if (referralRewardRate > 0) {
            return (_commission * referralRewardRate) / 100;
        }
        return 0;
    }

    function _processItemNative(CartItem memory item, uint256 gasLimit) private {
        uint256 lineTotal = _calculateLineTotal(item);
        address payable adminWallet = marketplaceAdminOf[item.seller];
        uint256 adminFeeRate = _getFeeRateForSeller(item.seller, address(0));
        uint256 adminShare = (lineTotal * adminFeeRate) / 100000;
        uint256 xpayrFee = xpayrFeeBps[adminWallet];
        uint256 xpayrShare = (lineTotal * xpayrFee) / 100000;

        if (adminShare + xpayrShare > lineTotal) revert FeesExceedTotal();
        
        uint256 referralReward = 0;
        address ref = userToReferrer[item.seller];
        if (ref != address(0)) {
            referralReward = _calculateReferralReward(xpayrShare);
        }
        
        if (xpayrShare >= referralReward) {
            xpayrShare -= referralReward;
            if (referralReward > 0) {
                claimableRewards[ref][address(0)] += referralReward;
            }
        } else {
            referralReward = 0;
        }

        uint256 netToSeller = lineTotal - adminShare - (xpayrShare + referralReward);
        if (netToSeller > 0) {
            (bool s, ) = item.seller.call{value: netToSeller, gas: gasLimit}("");
            if (!s) revert SellerPaymentFailed();
            // Removed redundant SellerPaid event
        }

        if (adminShare > 0) {
            (bool s, ) = adminWallet.call{value: adminShare}("");
            if (!s) revert AdminPaymentFailed();
        }

        if (xpayrShare > 0) {
            address payable target = xPayrWallets[uint256(walletIndex) % xPayrWallets.length];
            walletIndex++;
            (bool s, ) = target.call{value: xpayrShare}("");
            // Logic maintained, just no event
            if (s) {} 
        }
    }

    function _distributeMarketplacePayment(CartItem[] memory cartItems, uint256 /*grandTotal*/) internal {
        if (xPayrWallets.length == 0) revert NoXPayrWallet();
        uint256 gasLimit = networkConfigs[block.chainid].nativeTransferGasLimit;
        if (gasLimit == 0) gasLimit = 300000;
        for (uint i = 0; i < cartItems.length;) {
            _processItemNative(cartItems[i], gasLimit);
            unchecked { ++i; }
        }
    }

    function _processItemToken(CartItem memory item, IERC20MetadataUpgradeable token) private {
        uint256 lineTotal = _calculateLineTotal(item);
        address payable adminWallet = marketplaceAdminOf[item.seller];
        uint256 adminFeeRate = _getFeeRateForSeller(item.seller, address(token));
        uint256 adminShare = (lineTotal * adminFeeRate) / 100000;
        uint256 xpayrFee = xpayrFeeBps[adminWallet];
        uint256 xpayrShare = (lineTotal * xpayrFee) / 100000;

        if (adminShare + xpayrShare > lineTotal) revert FeesExceedTotal();
        
        uint256 referralReward = 0;
        address ref = userToReferrer[item.seller];
        if (ref != address(0)) {
            referralReward = _calculateReferralReward(xpayrShare);
        }

        if (xpayrShare >= referralReward) {
            xpayrShare -= referralReward;
            if (referralReward > 0) {
                claimableRewards[ref][address(token)] += referralReward;
            }
        } else {
            referralReward = 0;
        }

        uint256 netToSeller = lineTotal - adminShare - (xpayrShare + referralReward);
        if (netToSeller > 0) {
            token.safeTransfer(item.seller, netToSeller);
            // Removed redundant SellerPaid event
        }

        if (adminShare > 0) {
            token.safeTransfer(adminWallet, adminShare);
        }

        if (xpayrShare > 0) {
            address payable target = xPayrWallets[uint256(walletIndex) % xPayrWallets.length];
            walletIndex++;
            token.safeTransfer(target, xpayrShare);
        }
    }

    function _distributeMarketplaceTokenPayment(CartItem[] memory cartItems, IERC20MetadataUpgradeable token, uint256 /*grandTotal*/) internal {
        if (xPayrWallets.length == 0) revert NoXPayrWallet();
        for (uint i = 0; i < cartItems.length;) {
            _processItemToken(cartItems[i], token);
            unchecked { ++i; }
        }
    }

    function _getFeeRateForSeller(address _seller, address _token) internal view returns (uint256) {
        if (_token == xpayrTokenAddress && xpayrTokenAddress != address(0)) return 0;
        VendorSubscription memory sub = vendorSubscriptions[_seller];
        if (sub.expiresAt >= block.timestamp) {
            return subscriptionPlans[sub.planId].commissionRateBps;
        }
        return defaultCommissionRateBps;
    }

    // -------------------------
    // VIEW HELPERS
    // -------------------------
    function getContractBalance() external view returns (uint256) { return address(this).balance;
    }
    function getUserPayment(address u, address t) external view returns (uint256) { return userPayments[u][t];
    }
    function getTotalCollectedNative() external view returns (uint256) { return totalCollectedNative;
    }
    function getTotalCollectedUsdc() external view returns (uint256) { return totalCollectedUsdc;
    }
    function getTotalCollectedUsdt() external view returns (uint256) { return totalCollectedUsdt;
    }
    function getVendorSubscription(address v) external view returns (VendorSubscription memory) { return vendorSubscriptions[v];
    }
    function getSubscriptionPlan(uint8 id) external view returns (SubscriptionPlan memory) { return subscriptionPlans[id];
    }
    function getActivePlanIds() external view returns (uint8[] memory) { return activePlanIds;
    }
    function getAdminSubscription(address a) external view returns (AdminSubscription memory) { return adminSubscriptions[a];
    }
    function getPlatformPlan(uint8 id) external view returns (PlatformPlan memory) { return platformPlans[id];
    }
    function getAdminXPayrFee(address a) external view returns (uint256) { return xpayrFeeBps[a];
    }
    function getAdminOfSeller(address s) external view returns (address payable) { return marketplaceAdminOf[s]; }
}