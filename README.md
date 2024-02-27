# WhiskersBuilder

WhiskersBuilder builds a copy of the latest `wine` release and publishes it to a GitHub release.

## Local Development

Here are the required depedencies include:
- `curl` - Transfer data from or to a server
- `jq` - Command-line JSON processor
- `ditto` - Copy files and directories (should come with BSD-based systems)
- `tar` - Archiving utility

## Usage

```bash
./build.sh
```

You should end up with a `wine-build.txz` file in the root of this repository.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.