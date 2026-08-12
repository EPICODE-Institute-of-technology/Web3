# Deploy your own ERC-20 token (CourseToken)

This step does not produce an HTML page. It is a one-time step that
gives you a deployed `CourseToken` ERC-20 on Sepolia, whose address
you will plug into the pages that call it (07-call-token, 08-events, 09-minidapp).

## The contract

The source lives under `../contract/CourseToken.sol`. It composes three
OpenZeppelin building blocks:

- `ERC20`         — the standard balances, allowances, and `Transfer` event.
- `ERC20Burnable` — adds `burn(amount)` so any holder can destroy their own tokens.
- `Ownable`       — restricts `mint(to, amount)` to a single privileged address.

The constructor pre-mints **1 000 000 CRS** to the deployer.

## Deploying with Remix

1. Open <https://remix.ethereum.org>.
2. In the file explorer create a new file `CourseToken.sol` and paste the
   content of `../contract/CourseToken.sol`. Remix resolves the
   `@openzeppelin/contracts/...` imports automatically from npm — no
   manual install needed.
3. Switch to the **Solidity Compiler** tab.
   - Compiler: `0.8.20+commit…` (or any 0.8.20-compatible version).
   - Enable **Auto compile** or press **Compile CourseToken.sol**.
4. Switch to the **Deploy & run transactions** tab.
   - **Environment**: choose *Injected Provider — MetaMask*.
   - Make sure MetaMask is on **Sepolia**.
   - **Contract**: pick `CourseToken — CourseToken.sol`.
   - **Deploy** field: enter your own address as `initialOwner` (the
     account that will receive the 1 000 000 CRS and gain mint rights).
5. Press the orange **Deploy** button and confirm in MetaMask.
6. After the receipt arrives, the deployed contract appears under
   *Deployed Contracts*. Copy its address (starts with `0x…`).

## Recording the address

Paste the address you copied into the constant `TOKEN` at the top of
`07-call-token.html`, `08-events.html` and `09-minidapp.html`.

## Sanity check from the command line (optional)

```bash
export SEPOLIA=https://ethereum-sepolia-rpc.publicnode.com
export TOKEN=0xYourCourseTokenAddress
export ME=0xYourEOA

cast call $TOKEN "symbol()(string)"           --rpc-url $SEPOLIA
# → "CRS"

cast call $TOKEN "decimals()(uint8)"          --rpc-url $SEPOLIA
# → 18

cast call $TOKEN "totalSupply()(uint256)"     --rpc-url $SEPOLIA
# → 1000000000000000000000000   (1 000 000 × 10^18)

cast call $TOKEN "balanceOf(address)(uint256)" $ME --rpc-url $SEPOLIA
# → same as totalSupply (you are the initial owner)
```

## Optional: verify on Etherscan

Once deployed you can verify the source on
<https://sepolia.etherscan.io> by pasting the flattened source (Remix
plugin *Flattener*) and selecting the same compiler version + optimizer
settings you used during deployment. Verified contracts show a green
checkmark and a readable *Read / Write Contract* interface.
