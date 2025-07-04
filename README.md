# Public Notices

This is a [Git scraping](https://simonwillison.net/series/git-scraping/) mirror of Toronto's [Public Notices](https://open.toronto.ca/dataset/public-notices/) data set.

## Database

This project builds an SQLite database of the data, as well as a [Datasette](https://datasette.io/) image to explore the data.
Download the [latest version](https://github.com/benwebber/open-data-toronto-public-notices/releases/latest) of database from the [releases](https://github.com/benwebber/open-data-toronto-public-notices/releases) page.

Run the latest published image with Docker:

```
docker run -p 8000:8000 ghcr.io/benwebber/open-data-toronto-public-notices:latest
```

Or build the database locally and run the image with Docker Compose:

```
make public_notices.db
docker compose up
```

## Licence

The City of Toronto makes this data available under the terms of the [Open Government Licence – Toronto](https://open.toronto.ca/open-data-licence/).
