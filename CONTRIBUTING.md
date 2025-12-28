# Contributing to Web3Cart

Thank you for your interest in contributing to Web3Cart, the leading **crypto e-commerce platform** for building **no KYC**, decentralized marketplaces.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Smart Contract Development](#smart-contract-development)
- [Documentation](#documentation)

---

## 📜 Code of Conduct

This project adheres to a code of conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to support@web3cart.site.

---

## 🤝 How to Contribute

### Types of Contributions

1. **Bug Reports** - Found a bug? Open an issue with steps to reproduce.
2. **Feature Requests** - Have an idea? Propose new features.
3. **Documentation** - Improve docs, fix typos, add examples.
4. **Code** - Submit bug fixes or new features.
5. **Translations** - Help translate to new languages.
6. **Smart Contracts** - Improve Solidity escrow contracts.

### Good First Issues

Look for issues labeled `good-first-issue` for beginner-friendly tasks.

---

## 💻 Development Setup

### Prerequisites

```bash
# Required
PHP 8.1+
Composer 2.x
MySQL 8.0+
Node.js 18+
npm or yarn

# Optional (for smart contracts)
Solidity 0.8.26
Hardhat or Foundry
```

### Local Development

```bash
# 1. Fork and clone
git clone https://github.com/YOUR_USERNAME/Web3Cart-E-Commerce.git
cd Web3Cart-E-Commerce

# 2. Install dependencies
composer install
npm install

# 3. Configure environment
cp .env.example .env
# Edit .env with your database credentials

# 4. Set up database
php artisan migrate
php artisan db:seed

# 5. Build assets
npm run dev

# 6. Start development server
php artisan serve
```

### Docker Development

```bash
docker-compose up -d
```

---

## 🔄 Pull Request Process

### Before Submitting

1. **Check existing PRs** - Avoid duplicates
2. **Create an issue first** - Discuss major changes
3. **Follow code style** - PSR-12 for PHP
4. **Write tests** - Cover new functionality
5. **Update documentation** - Document new features

### PR Guidelines

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
How was this tested?

## Checklist
- [ ] Code follows style guidelines
- [ ] Tests pass locally
- [ ] Documentation updated
- [ ] No breaking changes
```

---

## ⛓️ Smart Contract Development

Web3Cart uses **Solidity 0.8.26** for escrow smart contracts.

### Contract Structure

```
contracts/
├── Escrow.sol           # Main escrow contract
├── MultiSigEscrow.sol   # Multi-signature escrow
├── TokenPayment.sol     # ERC-20 payment handler
└── interfaces/
    └── IEscrow.sol      # Escrow interface
```

### Testing Contracts

```bash
# Using Hardhat
npx hardhat test

# Using Foundry
forge test
```

### Security Guidelines

- All contracts must be audited before mainnet deployment
- Follow OpenZeppelin security patterns
- Use SafeMath for Solidity < 0.8.0
- Implement reentrancy guards
- Emit events for all state changes

---

## 📖 Documentation

### Documentation Structure

```
docs/
├── getting-started/
├── configuration/
├── multi-vendor/
├── payments/
├── smart-contracts/
└── api/
```

### Writing Documentation

- Use clear, concise language
- Include code examples
- Add screenshots for UI features
- Keep SEO keywords: crypto e-commerce, PHP script, blockchain marketplace

---

## 🏆 Recognition

Contributors are recognized in:
- README.md Contributors section
- Official documentation
- Discord contributor role

---

## 📞 Contact

- **Discord:** [Join Server](#)
- **Telegram:** [t.me/web3cart](https://t.me/web3cart)
- **Email:** dev@web3cart.site

---

**Thank you for contributing to the future of decentralized commerce!** 🚀
