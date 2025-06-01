# HattrickHarvester.jl

HattrickHarvester.jl is a Julia package for extracting player and transfer data from the Hattrick website, storing it as structured JSON files on disk, and later loading them into Julia for analysis.

## Features

- **Player Profiles**
  Fetch a player’s textual description and save it as a JSON file.
  _(Status: Working, under refinement)_

- **Transfer Histories**
  Retrieve a player’s transfer events and store them in JSON format.
  _(Status: Working, under refinement)_

- **Full Archive Import**
  Download the entire archive of player data and build a `DataFrame`.
  _(Status: Planned)_

- **Graphical User Interface**
  Using the package through a GUI, for user convenience.
  _(Status: Planned)_

## Development

Contributions, bug reports, and feature requests are very welcome!

1. Fork the repository
2. Create a feature branch (`git checkout -b feature-name`)
3. Commit your changes and push (`git push origin feature-name`)
4. Open a Pull Request on GitHub

Make sure all tests pass locally; CI is configured with GitHub Actions.

## License

Released under the [MIT License](LICENSE.md).
