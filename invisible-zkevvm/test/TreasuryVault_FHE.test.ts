import { expect } from "chai";
import { ethers, fhevm } from "hardhat";
import { Contract, Signer } from "ethers";
import { FhevmType } from "@fhevm/hardhat-plugin";

async function createEncryptedEuint64(
  contractAddress: string,
  userAddress: string,
  value: bigint | number
) {
  const enc = await fhevm
    .createEncryptedInput(contractAddress, userAddress)
    .add64(typeof value === "bigint" ? Number(value) : value)
    .encrypt();
  return enc;
}

async function decryptEuint64(
  contractAddress: string,
  encrypted: any,
  signer: Signer
): Promise<bigint> {
  const clear = await fhevm.userDecryptEuint(
    FhevmType.euint64,
    encrypted,
    contractAddress,
    signer
  );
  return BigInt(clear);
}

describe("TreasuryVault (FHE)", function () {
  let admin: Signer;
  let governor: Signer;
  let user: Signer;
  let TreasuryVault: any;
  let treasury: Contract;
  let mockToken: Contract;

  beforeEach(async function () {
    [admin, governor, user] = await ethers.getSigners();

    const TreasuryVaultFactory = await ethers.getContractFactory("TreasuryVault");
    treasury = await TreasuryVaultFactory.connect(admin).deploy(ethers.ZeroAddress);
    await treasury.waitForDeployment();

    // Add a second governor for negative tests
    await treasury.connect(admin).addGovernor(await governor.getAddress());

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    mockToken = await MockERC20.connect(admin).deploy("Mock", "MOCK");
    await mockToken.waitForDeployment();
  });

  describe("deposit", function () {
    it("deposits ETH and increases encrypted totals", async function () {
      const userAddr = await user.getAddress();
      const treasuryAddr = await treasury.getAddress();

      const amount = ethers.parseEther("0.01");
      const enc = await createEncryptedEuint64(treasuryAddr, userAddr, amount);

      await expect(
        treasury
          .connect(user)
          .deposit(ethers.ZeroAddress, enc.handles[0], enc.inputProof, { value: amount })
      ).to.emit(treasury, "Deposited");

      const [total, reserved, available] = await treasury.getTreasuryBalance(ethers.ZeroAddress);
      const totalClear = await decryptEuint64(treasuryAddr, total, user);
      const reservedClear = await decryptEuint64(treasuryAddr, reserved, user);
      const availableClear = await decryptEuint64(treasuryAddr, available, user);

      expect(totalClear).to.equal(amount);
      expect(reservedClear).to.equal(0n);
      expect(availableClear).to.equal(amount);
      expect(await ethers.provider.getBalance(treasuryAddr)).to.equal(amount);
    });

    it("deposits ERC20 (no ETH) and updates encrypted totals", async function () {
      const userAddr = await user.getAddress();
      const treasuryAddr = await treasury.getAddress();
      const amount = ethers.parseUnits("10", 18);

      // Mint tokens to user and approve transfer to treasury (transfer is external in MVP)
      await mockToken.connect(admin).mint(userAddr, amount);
      await mockToken.connect(user).approve(treasuryAddr, amount);

      const enc = await createEncryptedEuint64(treasuryAddr, userAddr, amount);
      await expect(
        treasury.connect(user).deposit(await mockToken.getAddress(), enc.handles[0], enc.inputProof)
      ).to.emit(treasury, "Deposited");

      const [total, , available] = await treasury.getTreasuryBalance(await mockToken.getAddress());
      const totalClear = await decryptEuint64(treasuryAddr, total, user);
      const availableClear = await decryptEuint64(treasuryAddr, available, user);
      expect(totalClear).to.equal(amount);
      expect(availableClear).to.equal(amount);
    });

    it("reverts when depositing ETH with zero msg.value", async function () {
      const userAddr = await user.getAddress();
      const treasuryAddr = await treasury.getAddress();
      const amount = 0;
      const enc = await createEncryptedEuint64(treasuryAddr, userAddr, amount);

      await expect(
        treasury
          .connect(user)
          .deposit(ethers.ZeroAddress, enc.handles[0], enc.inputProof, { value: 0 })
      ).to.be.revertedWith("Amount must be > 0");
    });

    it("reverts when depositing ERC20 with non-zero msg.value", async function () {
      const userAddr = await user.getAddress();
      const treasuryAddr = await treasury.getAddress();
      const amount = ethers.parseUnits("1", 18);
      const enc = await createEncryptedEuint64(treasuryAddr, userAddr, amount);

      await expect(
        treasury
          .connect(user)
          .deposit(await mockToken.getAddress(), enc.handles[0], enc.inputProof, {
            value: ethers.parseEther("0.001"),
          })
      ).to.be.revertedWith("No ETH for ERC20");
    });
  });

  describe("withdrawal with timelock", function () {
    it("onlyGovernance can request withdrawal and timelock enforced", async function () {
      const userAddr = await user.getAddress();
      const treasuryAddr = await treasury.getAddress();
      const token = ethers.ZeroAddress;
      const amount = ethers.parseEther("0.005");

      // First deposit ETH
      const encDep = await createEncryptedEuint64(treasuryAddr, userAddr, amount);
      await treasury
        .connect(user)
        .deposit(token, encDep.handles[0], encDep.inputProof, { value: amount });

      // Non-governor cannot request withdrawal
      const encWNoGov = await createEncryptedEuint64(treasuryAddr, await user.getAddress(), amount);
      await expect(
        treasury
          .connect(user)
          .requestWithdrawal(token, encWNoGov.handles[0], encWNoGov.inputProof, await user.getAddress())
      ).to.be.revertedWith("Not governor");

      // Governor can request
      const encW = await createEncryptedEuint64(treasuryAddr, await governor.getAddress(), amount);
      const tx = await treasury
        .connect(governor)
        .requestWithdrawal(token, encW.handles[0], encW.inputProof, await user.getAddress());
      const rc = await tx.wait();
      const ev = rc!.logs.find((l: any) => l.fragment?.name === "WithdrawalRequested");
      const requestId = ev?.args?.requestId ?? 0n;

      // Before timelock expires, executing should revert
      await expect(treasury.connect(user).executeWithdrawal(requestId, token)).to.be.revertedWith(
        "Timelock not expired"
      );

      // Increase time by 2 days and mine a block
      await ethers.provider.send("evm_increaseTime", [2 * 24 * 60 * 60]);
      await ethers.provider.send("evm_mine", []);

      // Execute withdrawal after timelock
      await expect(treasury.connect(user).executeWithdrawal(requestId, token)).to.emit(
        treasury,
        "WithdrawalExecuted"
      );

      // Verify encrypted balance decreased (totalBalance becomes 0)
      const [total, reserved, available] = await treasury.getTreasuryBalance(token);
      const totalClear = await decryptEuint64(treasuryAddr, total, user);
      const reservedClear = await decryptEuint64(treasuryAddr, reserved, user);
      const availableClear = await decryptEuint64(treasuryAddr, available, user);
      expect(totalClear).to.equal(0n);
      expect(reservedClear).to.equal(0n);
      expect(availableClear).to.equal(0n);
    });
  });
});


