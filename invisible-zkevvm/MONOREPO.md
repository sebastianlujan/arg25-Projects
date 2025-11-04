# Estructura del Monorepo

Este proyecto es un repositorio monolítico que contiene tanto contratos inteligentes en **Solidity** (usando Hardhat) como contratos en **Stylus** (usando Rust).

## Estructura de Carpetas

```
invisible-zkevvm/
├── contracts/          # Contratos Solidity
├── scripts/            # Scripts de despliegue (Hardhat)
├── test/               # Tests para contratos Solidity
├── src/                # Código fuente Stylus (Rust)
├── examples/           # Ejemplos de Stylus
├── hardhat.config.js   # Configuración de Hardhat
├── package.json        # Dependencias Node.js/Hardhat
├── Cargo.toml          # Dependencias Rust/Stylus
└── rust-toolchain.toml # Versión de Rust toolchain
```

## Trabajando con Solidity (Hardhat)

### Instalación

```bash
npm install
```

### Compilar contratos

```bash
npm run compile
# o
npx hardhat compile
```

### Ejecutar tests

```bash
npm test
# o
npx hardhat test
```

### Desplegar contratos

```bash
npm run deploy -- --network arbitrumSepolia
# o
npx hardhat run scripts/deploy.js --network arbitrumSepolia
```

### Redes disponibles

- `hardhat`: Red local de desarrollo
- `arbitrumSepolia`: Arbitrum Sepolia testnet
- `arbitrumOne`: Arbitrum One mainnet

**Nota**: Necesitarás configurar las variables de entorno en un archivo `.env`:
```
PRIVATE_KEY=tu_clave_privada
ARBITRUM_SEPOLIA_RPC_URL=https://sepolia-rollup.arbitrum.io/rpc
ARBITRUM_ONE_RPC_URL=https://arb1.arbitrum.io/rpc
```

## Trabajando con Stylus (Rust)

### Compilar contratos Stylus

```bash
cargo stylus build
```

### Verificar contratos

```bash
cargo stylus check
```

### Desplegar contratos Stylus

```bash
cargo stylus deploy
```

### Ejecutar tests

```bash
cargo test
```

## Flujo de Trabajo

### Desarrollo de Solidity

1. Escribe tus contratos en `contracts/`
2. Crea tests en `test/`
3. Ejecuta `npm test` para probar
4. Despliega con `npm run deploy`

### Desarrollo de Stylus

1. Escribe tus contratos en `src/lib.rs` o `examples/`
2. Crea tests en el mismo archivo usando `#[cfg(test)]`
3. Ejecuta `cargo test` para probar
4. Compila con `cargo stylus build`
5. Despliega con `cargo stylus deploy`

## Ventajas de este Monorepo

- ✅ Un solo repositorio para ambos tipos de contratos
- ✅ Compartir código y utilidades entre proyectos
- ✅ Testing unificado
- ✅ Gestión de dependencias centralizada
- ✅ Fácil comparación entre implementaciones Solidity y Stylus

## Ejemplo: Counter

Este monorepo incluye implementaciones del contrato Counter tanto en Solidity (`contracts/Counter.sol`) como en Stylus (`src/lib.rs`), permitiendo comparar ambas aproximaciones.

