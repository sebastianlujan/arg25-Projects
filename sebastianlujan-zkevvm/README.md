# ARG25 Project Submission Template

Welcome to Invisible Garden- ARG25.

Each participant or team will maintain this README throughout the program.  
You'll update your progress weekly **in the same PR**, so mentors and reviewers can track your journey end-to-end.



##  Project Title
**zkEvvm - Stylus Smart Contract Project**

## Team
- Team/Individual Name: Sebastian Lujan
- GitHub Handles: sebastianlujan
- Devfolio Handles: 

## Project Description
_What are you building and why does it matter? Explain the core problem and your proposed solution._

Este proyecto es una implementación de un contrato inteligente Counter en Rust usando Arbitrum Stylus SDK. El contrato permite:
- Almacenar y consultar un número
- Establecer un número específico
- Incrementar el contador
- Realizar operaciones matemáticas (multiplicación y suma)
- Aceptar pagos en wei y agregarlos al contador

Stylus permite escribir contratos inteligentes en Rust y compilarlos a WASM, ofreciendo mejor rendimiento y acceso a las características de Rust mientras mantiene compatibilidad ABI con Solidity.

## Tech Stack
_List all the technologies, frameworks, and tools you are using._

- **Rust** - Lenguaje de programación principal
- **Arbitrum Stylus SDK** (v0.9.0) - SDK para desarrollar contratos en Stylus
- **Alloy Primitives** (v0.8.20) - Tipos primitivos de Ethereum
- **cargo-stylus** - Herramienta CLI para compilar, verificar y desplegar contratos Stylus
- **WASM** - Compilación objetivo para Stylus
- **Ethers.rs** - Para interactuar con el contrato desde Rust

## Objectives
_What are the specific outcomes you aim to achieve by the end of ARG25?_

- Implementar y desplegar un contrato inteligente funcional en Arbitrum Stylus
- Entender el flujo de desarrollo completo de Stylus (compilación, verificación, despliegue)
- Explorar las ventajas de escribir contratos en Rust vs Solidity
- Interactuar con el contrato desplegado usando herramientas de Ethereum
- Documentar el proceso y compartir conocimientos con la comunidad

## Weekly Progress

### Week 1 (ends Oct 31)
**Goals:**
- Configurar el entorno de desarrollo Stylus
- Implementar el contrato Counter básico
- Compilar y verificar el contrato

**Progress Summary:**  
Proyecto inicializado con cargo-stylus. Contrato Counter implementado con funciones básicas (set_number, increment, add_number, mul_number). Código compilado exitosamente a WASM. Verificación de compatibilidad con Stylus completada.


### Week 2 (ends Nov 7)
**Goals:**  
- Desplegar el contrato en testnet
- Probar las funciones del contrato
- Crear ejemplos de interacción

**Progress Summary:**  


### 🗓️ Week 3 (ends Nov 14)
**Goals:**  

**Progress Summary:**  



## Final Wrap-Up
_After Week 3, summarize your final state: deliverables, repo links, and outcomes._

- **Main Repository Link:** https://github.com/sebastianlujan/arg25-Projects/tree/main/sebastianlujan-zkevvm
- **Demo / Deployment Link (if any):**  
- **Slides / Presentation (if any):**



## 🧾 Learnings
_What did you learn or improve during ARG25?_

- Desarrollo de contratos inteligentes en Rust usando Stylus SDK
- Compilación de Rust a WASM para ejecución en blockchain
- Flujo de despliegue en Arbitrum Stylus testnet
- Integración de herramientas de desarrollo para Stylus (cargo-stylus)



## Next Steps
_If you plan to continue development beyond ARG25, what's next?_

- Desplegar el contrato en testnet y realizar pruebas exhaustivas
- Implementar funciones más complejas y explorar características avanzadas de Stylus
- Optimizar el tamaño del binario WASM
- Crear una interfaz de usuario para interactuar con el contrato
- Explorar casos de uso más avanzados para Stylus


## Documentación Técnica

Para más detalles sobre cómo usar este proyecto, consulta [assets/README-original.md](assets/README-original.md).


_This template is part of the [ARG25 Projects Repository](https://github.com/invisible-garden/arg25-projects)._  
_Update this file weekly by committing and pushing to your fork, then raising a PR at the end of each week._

