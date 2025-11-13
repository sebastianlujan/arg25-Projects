const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Counter", function () {
  let counter;

  beforeEach(async function () {
    const Counter = await ethers.getContractFactory("Counter");
    counter = await Counter.deploy();
    await counter.waitForDeployment();
  });

  it("Debería inicializar con number = 0", async function () {
    expect(await counter.number()).to.equal(0);
  });

  it("Debería establecer un número", async function () {
    await counter.setNumber(42);
    expect(await counter.number()).to.equal(42);
  });

  it("Debería incrementar el número", async function () {
    await counter.increment();
    expect(await counter.number()).to.equal(1);
    
    await counter.increment();
    expect(await counter.number()).to.equal(2);
  });

  it("Debería sumar un valor al número", async function () {
    await counter.setNumber(10);
    await counter.addNumber(5);
    expect(await counter.number()).to.equal(15);
  });

  it("Debería multiplicar el número", async function () {
    await counter.setNumber(5);
    await counter.mulNumber(3);
    expect(await counter.number()).to.equal(15);
  });

  it("Debería añadir el valor enviado en wei", async function () {
    const [owner] = await ethers.getSigners();
    const value = ethers.parseEther("1.0");
    
    await counter.addFromMsgValue({ value });
    expect(await counter.number()).to.equal(value);
  });
});

