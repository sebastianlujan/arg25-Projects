import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { ethers, fhevm, deployments } from "hardhat";
import { EVVMCore, TreasuryVault } from "../types";
import { expect } from "chai";
import { FhevmType } from "@fhevm/hardhat-plugin";

type Signers = {
  admin: HardhatEthersSigner;
  user1: HardhatEthersSigner;
  user2: HardhatEthersSigner;
  executor: HardhatEthersSigner;
};

describe("EVVMCore Payments with FHE", function () {
  let signers: Signers;
  let evvmCore: EVVMCore;
  let treasury: TreasuryVault;
  let evvmCoreAddress: string;
  let treasuryAddress: string;
  let step: number;
  let steps: number;

  const ETHER_ADDRESS = ethers.ZeroAddress;
  const TEST_AMOUNT = 1000;
  const TEST_PRIORITY_FEE = 100;
  const TEST_EVVM_ID = 777;

  function progress(message: string) {
    console.log(`${++step}/${steps} ${message}`);
  }

  before(async function () {
    if (fhevm.isMock) {
      console.warn(`This test suite requires FHE SDK - skipping on mock network`);
      this.skip();
    }

    try {
      const EVVMCoreDeployment = await deployments.get("EVVMCore");
      evvmCoreAddress = EVVMCoreDeployment.address;
      evvmCore = await ethers.getContractAt("EVVMCore", evvmCoreAddress);

      const TreasuryDeployment = await deployments.get("TreasuryVault");
      treasuryAddress = TreasuryDeployment.address;
      treasury = await ethers.getContractAt("TreasuryVault", treasuryAddress);
    } catch (e) {
      (e as Error).message += ". Call 'npx hardhat deploy --network sepolia'";
      throw e;
    }

    const ethSigners: HardhatEthersSigner[] = await ethers.getSigners();
    signers = {
      admin: ethSigners[0],
      user1: ethSigners[1],
      user2: ethSigners[2],
      executor: ethSigners[3],
    };
  });

  beforeEach(async () => {
    step = 0;
    steps = 0;
  });

  it("should add balance to user via treasury", async function () {
    steps = 5;
    this.timeout(4 * 40000);

    progress(`Encrypting amount ${TEST_AMOUNT}...`);
    const encryptedAmount = await fhevm
      .createEncryptedInput(treasuryAddress, signers.user1.address)
      .add64(TEST_AMOUNT)
      .encrypt();

    progress(`Calling treasury.addAmountToUser()...`);
    const tx = await treasury
      .connect(signers.admin)
      .addAmountToUser(
        signers.user1.address,
        ETHER_ADDRESS,
        encryptedAmount.handles[0],
        encryptedAmount.inputProof
      );
    await tx.wait();

    progress(`Calling evvmCore.getBalance()...`);
    const encryptedBalance = await evvmCore.getBalance(signers.user1.address, ETHER_ADDRESS);

    progress(`Decrypting balance...`);
    const clearBalance = await fhevm.userDecryptEuint(
      FhevmType.euint64,
      encryptedBalance,
      evvmCoreAddress,
      signers.user1
    );

    progress(`Clear balance: ${clearBalance}`);
    expect(clearBalance).to.eq(TEST_AMOUNT);
  });

  it("should process payment without signature verification", async function () {
    steps = 10;
    this.timeout(4 * 40000);

    // First, add balance to user1
    progress(`Adding balance to user1...`);
    const encryptedInitialBalance = await fhevm
      .createEncryptedInput(treasuryAddress, signers.user1.address)
      .add64(TEST_AMOUNT + TEST_PRIORITY_FEE)
      .encrypt();

    await treasury
      .connect(signers.admin)
      .addAmountToUser(
        signers.user1.address,
        ETHER_ADDRESS,
        encryptedInitialBalance.handles[0],
        encryptedInitialBalance.inputProof
      );

    // Encrypt payment amount
    progress(`Encrypting payment amount ${TEST_AMOUNT}...`);
    const encryptedAmount = await fhevm
      .createEncryptedInput(evvmCoreAddress, signers.user1.address)
      .add64(TEST_AMOUNT)
      .encrypt();

    // Encrypt priority fee
    progress(`Encrypting priority fee ${TEST_PRIORITY_FEE}...`);
    const encryptedFee = await fhevm
      .createEncryptedInput(evvmCoreAddress, signers.user1.address)
      .add64(TEST_PRIORITY_FEE)
      .encrypt();

    // Get initial balances
    progress(`Getting initial balances...`);
    const encryptedBalanceUser1Before = await evvmCore.getBalance(signers.user1.address, ETHER_ADDRESS);
    const encryptedBalanceUser2Before = await evvmCore.getBalance(signers.user2.address, ETHER_ADDRESS);

    const clearBalanceUser1Before = await fhevm.userDecryptEuint(
      FhevmType.euint64,
      encryptedBalanceUser1Before,
      evvmCoreAddress,
      signers.user1
    );

    const clearBalanceUser2Before = await fhevm.userDecryptEuint(
      FhevmType.euint64,
      encryptedBalanceUser2Before,
      evvmCoreAddress,
      signers.user2
    );

    // Process payment
    progress(`Processing payment...`);
    const paymentParams = {
      from: signers.user1.address,
      to: signers.user2.address,
      toIdentity: "",
      token: ETHER_ADDRESS,
      amountPlaintext: TEST_AMOUNT,
      inputEncryptedAmount: encryptedAmount.handles[0],
      inputAmountProof: encryptedAmount.inputProof,
      priorityFeePlaintext: TEST_PRIORITY_FEE,
      inputEncryptedPriorityFee: encryptedFee.handles[0],
      inputFeeProof: encryptedFee.inputProof,
      nonce: 1,
      priorityFlag: true, // async nonce
      executor: ethers.ZeroAddress,
      signature: "0x",
    };

    const tx = await evvmCore.connect(signers.user1).pay(paymentParams);
    await tx.wait();

    // Verify balances
    progress(`Verifying balances...`);
    const encryptedBalanceUser1After = await evvmCore.getBalance(signers.user1.address, ETHER_ADDRESS);
    const encryptedBalanceUser2After = await evvmCore.getBalance(signers.user2.address, ETHER_ADDRESS);

    const clearBalanceUser1After = await fhevm.userDecryptEuint(
      FhevmType.euint64,
      encryptedBalanceUser1After,
      evvmCoreAddress,
      signers.user1
    );

    const clearBalanceUser2After = await fhevm.userDecryptEuint(
      FhevmType.euint64,
      encryptedBalanceUser2After,
      evvmCoreAddress,
      signers.user2
    );

    progress(`User1 balance: ${clearBalanceUser1Before} -> ${clearBalanceUser1After}`);
    progress(`User2 balance: ${clearBalanceUser2Before} -> ${clearBalanceUser2After}`);

    expect(clearBalanceUser1After).to.eq(clearBalanceUser1Before - TEST_AMOUNT - TEST_PRIORITY_FEE);
    expect(clearBalanceUser2After).to.eq(clearBalanceUser2Before + TEST_AMOUNT);
  });

  it("should process payment with signature verification", async function () {
    steps = 15;
    this.timeout(4 * 40000);

    // Enable signature verification
    progress(`Enabling signature verification...`);
    await evvmCore.connect(signers.admin).setSignatureVerificationRequired(true);

    // Add balance
    const encryptedInitialBalance = await fhevm
      .createEncryptedInput(treasuryAddress, signers.user1.address)
      .add64(TEST_AMOUNT + TEST_PRIORITY_FEE)
      .encrypt();

    await treasury
      .connect(signers.admin)
      .addAmountToUser(
        signers.user1.address,
        ETHER_ADDRESS,
        encryptedInitialBalance.handles[0],
        encryptedInitialBalance.inputProof
      );

    // Encrypt values
    progress(`Encrypting payment values...`);
    const encryptedAmount = await fhevm
      .createEncryptedInput(evvmCoreAddress, signers.user1.address)
      .add64(TEST_AMOUNT)
      .encrypt();

    const encryptedFee = await fhevm
      .createEncryptedInput(evvmCoreAddress, signers.user1.address)
      .add64(TEST_PRIORITY_FEE)
      .encrypt();

    // Create signature
    progress(`Creating signature...`);
    const evvmID = await evvmCore.evvmID();
    const message = `${evvmID},pay,${signers.user2.address.toLowerCase()},${ETHER_ADDRESS.toLowerCase()},${TEST_AMOUNT},${TEST_PRIORITY_FEE},1,true,${ethers.ZeroAddress.toLowerCase()}`;
    const signature = await signers.user1.signMessage(ethers.getBytes(ethers.toUtf8Bytes(message)));

    // Process payment with signature
    progress(`Processing payment with signature...`);
    const paymentParams = {
      from: signers.user1.address,
      to: signers.user2.address,
      toIdentity: "",
      token: ETHER_ADDRESS,
      amountPlaintext: TEST_AMOUNT,
      inputEncryptedAmount: encryptedAmount.handles[0],
      inputAmountProof: encryptedAmount.inputProof,
      priorityFeePlaintext: TEST_PRIORITY_FEE,
      inputEncryptedPriorityFee: encryptedFee.handles[0],
      inputFeeProof: encryptedFee.inputProof,
      nonce: 1,
      priorityFlag: true,
      executor: ethers.ZeroAddress,
      signature: signature,
    };

    const tx = await evvmCore.connect(signers.user1).pay(paymentParams);
    await tx.wait();

    progress(`Payment processed successfully with signature verification`);
  });
});

