// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Counter
 * @dev Un contrato simple que implementa un contador
 * Este contrato es equivalente al contrato Counter en Stylus
 */
contract Counter {
    uint256 public number;

    /**
     * @dev Establece el número a un valor específico
     * @param newNumber El nuevo valor para el número
     */
    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    /**
     * @dev Incrementa el número en 1
     */
    function increment() public {
        number++;
    }

    /**
     * @dev Suma un valor al número actual
     * @param value El valor a sumar
     */
    function addNumber(uint256 value) public {
        number += value;
    }

    /**
     * @dev Multiplica el número actual por un valor
     * @param value El valor multiplicador
     */
    function mulNumber(uint256 value) public {
        number *= value;
    }

    /**
     * @dev Añade el valor enviado en wei al número
     */
    function addFromMsgValue() public payable {
        number += msg.value;
    }
}

