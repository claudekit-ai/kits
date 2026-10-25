# Claudekit kits

Free Claude Code plugins from [Claudekit.ai](https://claudekit.ai). Each kit has a recipe page that shows the test level it actually reached: static, smoke, e2e or human. See [how we test](https://claudekit.ai/how-we-test/).

Claudekit.ai is an independent community project. Not affiliated with, endorsed by, or sponsored by Anthropic. Claude is a trademark of Anthropic, PBC.

## Install

In Claude Code:

```text
/plugin marketplace add claudekit-ai/kits
/plugin install safe-mode@claudekit
```

| Kit | What it does | Recipe |
|---|---|---|
| `usage-meter` | Status line with model, context use and your 5-hour and weekly plan usage (Pro and Max) | [recipe](https://claudekit.ai/recipes/usage-meter/) |
| `safe-mode` | Denies or asks before destructive shell commands | [recipe](https://claudekit.ai/recipes/safe-mode/) |
| `token-diet` | Audits what fills your context and suggests documented trims | [recipe](https://claudekit.ai/recipes/token-diet/) |
| `pr-review` | Reviews your branch diff with a fixed checklist, writes REVIEW.md | [recipe](https://claudekit.ai/recipes/pr-review/) |
| `release-notes` | Drafts release notes from git log between two refs | [recipe](https://claudekit.ai/recipes/release-notes/) |

Each kit can also be downloaded as a zip from its recipe page and loaded with `claude --plugin-dir ./<kit>.zip`.

## Tests

`bash tests/run-all.sh` runs every kit's static tests. Requires bash, git and jq.

## Reporting problems

Open an issue in this repository. Security problems in `safe-mode`: please open an issue titled "security" without exploit details and we will reach out.

## License

MIT, see [LICENSE](LICENSE). This repository is published from the `kits/` folder of the Claudekit.ai source; pull requests are welcome and are applied there.
