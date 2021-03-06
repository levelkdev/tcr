/* global artifacts */

const Token = artifacts.require('tokens/eip20/EIP20.sol');

const fs = require('fs');

module.exports = (deployer, network) => {
  const config = JSON.parse(fs.readFileSync('./conf/config.json'));

  async function giveTokensTo(tokenHolders) {
    if (tokenHolders.length === 0) { return; }
    const token = await Token.deployed();
    const tokenHolder = tokenHolders[0];

    // eslint-disable-next-line
    console.log(`Allocating ${tokenHolder.amount} ${config.token.symbol} tokens to ` +
    `${tokenHolder.address}.`);

    await token.transfer(tokenHolder.address, tokenHolder.amount);

    const receipt = await giveTokensTo(tokenHolders.slice(1));
    return receipt
  }

  if (config.token.deployToken) {
    return deployer.deploy(
      Token, config.token.supply, config.token.name, config.token.decimals,
      config.token.symbol,
    )
      .then(async () => {
        const receipt = await giveTokensTo(config.token.tokenHolders)
        return receipt
      })
  } else {
    // eslint-disable-next-line
    console.log('skipping optional token deploy and using the token at address ' +
      `${config.token.address} on network ${network}.`);
  }
};
