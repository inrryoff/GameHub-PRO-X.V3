# 🎮 GameHub-PRO-X

[![Magisk](https://img.shields.io/badge/Magisk-27.0+-green.svg)](https://github.com/topjohnwu/Magisk)
[![Android](https://img.shields.io/badge/Android-12+-blue.svg)](https://www.android.com)
[![Device](https://img.shields.io/badge/Device-Moto_G24-orange.svg)](https://motorola.com)

O **GameHub** é um ecossistema de otimização de baixo nível desenvolvido especificamente para extrair o máximo de performance da linha Moto G24.

---

## ⚠️ AVISO DE COMPATIBILIDADE (LEIA!)

Este módulo **NÃO** é genérico. Ele foi projetado sob medida:
*   **📱 Dispositivo Alvo:** Exclusivo para **Moto G24**.
*   **⚡ Compatibilidade:** Testado apenas no **Moto G24** porém presuma-se que seja compatível com o **Moto G24** e dispositivos com SoC **mt6768 & mt6769** (Hélio G80/G85).
*   **🛠️ Ambiente:** Desenvolvido e testado na **GSI: CrDroid**.

---

## 💢 ATENÇÃO

> [!CAUTION]
>  **Atenção aos riscos de uso excessivo**
> - **Superaquecimento**: Use com cooler externo (obrigatório para sessões longas)
> - **Bateria**: O consumo será maior devido à prioridade máxima da CPU
> - **Estabilidade**: Pode causar lentidão no sistema fora do jogo

---

## 🆕 Novidade na V5!

> [!TIP]
> O **GameHub-PRO-X** agora utiliza o [RGB-Banner](https://github.com/inrryoff/neon-cat) para exibições de banners animados em tempo real.
>
> **Diferenciais técnicos:**
> - **Performance em C:** Desenvolvido em C puro para ser infinitamente mais leve que scripts em Python ou Ruby.
> - **Zero Lag:** Processamento via movimentação relativa de cursor, garantindo fluidez total sem "clonar" o texto ou travar o scroll do terminal.
> - **Superioridade:** Supera o `lolcat` original ao lidar com grandes blocos de texto e caracteres Unicode complexos sem quebras.

---

## 📱 Dispositivos compatíveis

| Dispositivo | Codinome | Modelo | SoC | compatibilidade |
|-------------|----------|--------|-----|------|
| Moto G24 | fogorow | XT2423, XT2425 | Helio G85 | sim |
| Moto G24 Power | fogorow | XT2425 | Helio G85 | talvez |
| Outros Helio G85/G80 | - | - | MT6768/MT6769 | ? |

---

## 📊 Otimizações aplicadas

| Recurso | O que faz | Comando |
|---------|-----------|---------|
| CPU | Prioridade máxima | `chrt -f -p 99` + `renice -20` |
| I/O | Tempo real | `ionice -c 1 -n 0` |
| Memória | Proteção OOM | `oom_score_adj -1000` |
| GPU | Vulkan forçado | `debug.hwui.renderer skiavk` |

---

## 🐛 Reportar problemas

Abra uma issue no GitHub com:
- Modelo do celular
- ROM (Stock/GSI)
- Log do módulo: `/data/local/tmp/logs/gamehub.log`

---

## 🛡️ REQUISITOS OBRIGATÓRIOS

1. Este módulo funciona em simbiose com o *ZramTG24* e o *BuSy.* É **obrigatória** a instalação dos módulos abaixo:
- 👉 **[ZramTG24](https://github.com/inrryoff/ZramTG24)**
- 👉 **[BuSy](https://github.com/inrryoff/BuSy)**

- O GameHub-PRO-X aciona o motor `ram.sh` do ZramTG24 para garantir que a Zram esteja limpa e comprimida antes de injetar os perfis de performance no kernel.
- O GameHub-PRO-X utiliza comandos mais avançados que exigem a instalação do BuSy, o nível de instalação recomendado para o GameHub-PRO-X é a `Small` mas funciona perfeitamente com os níveis `Full` e `Medium`.

---

### ✔️ Instalação recomendada

Recomendo baixar o módulo [Kreapic Desativar Térmico Universal](https://github.com/mahisataruna/Kreapic-Disable-Thermal) 

---

## 🚀 Instalação

1. Baixe o arquivo ".zip" do módulo.
2. Abra o app do [Magisk](https://github.com/topjohnwu/magisk/releases).
3. Vá na aba de módulos.
4. Selecione instalar do armazenamento.
5. selecione o arquivo do GameHub-PRO-X.
6. Reinicie o dispositivo.

---

## 🛠️ Como Utilizar

O módulo já configura o binário no sistema via `customize.sh`.
1. Abra o **[Termux](https://github.com/termux/termux-app)**.
2. Digite `play` ou`su -c /data/adb/modules/GameHub-PRO-X/system/bin/booster.sh`
3. Siga o menu para adicionar jogos, configurar a whitelist ou iniciar a jogatina.

---

## 👤 Créditos e Licença

* **Desenvolvedor**: [@inrryoff](https://github.com/inrryoff)
* **Licença:** MIT (Pode usar e modificar, desde que mantenha os créditos ao autor original).
* **Projeto**: GameHub-PRO-X

---

## 🙏 Agradecimentos

- **[Termux](https://github.com/termux)** - Terminal emulador para Android (GPL v3.0)
- **[Magisk](https://github.com/topjohnwu/magisk)** - A base de tudo
