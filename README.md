The rustup.sh is used for installing from Rust release channels.

## Examples

Download and install the default channel, currently beta.

```
rustup.sh
```

Install to a particular location.

```
rustup.sh --prefix=my/install/dir
```

Save downloads for faster re-installs.

```
rustup.sh --save
```

Install nightly.

```
rustup.sh --channel=nightly
```

Install nightly archives.

```
rustup.sh --channel=nightly --date=2015-04-09
```
