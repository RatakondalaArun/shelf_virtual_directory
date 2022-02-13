# Change Log

## 3.0.1

- Upgraded dependencies
- Fixed linter warnings

## 3.0.0

Complete rewrite of this package.

### Major changes

- Removed [`showLogs`](https://github.com/RatakondalaArun/shelf_virtual_directory/blob/v2.0.0/lib/src/virtual_directory.dart#L78) argument.
- Now `folderPath` takes a [absolute path](https://www.hackterms.com/absolute%20path).

### Minor changes

- Upgrade dependencies
- Added support for range requests [#19](https://github.com/RatakondalaArun/shelf_virtual_directory/pull/19).
- Issues Fixed
  - New files does not get served untill application restart [#15](https://github.com/RatakondalaArun/shelf_virtual_directory/issues/15)
  - rootFolderName get failed [#16](https://github.com/RatakondalaArun/shelf_virtual_directory/issues/16)

## 2.0.0

- nullsafety to stable

## 2.0.0-nullsafety.0

- Removed test dependency.
- Migration to nullsafety prerelease [#6](https://github.com/RatakondalaArun/shelf_virtual_directory/issues/6).

## 1.0.1

- bumped shelf version [#4](https://github.com/RatakondalaArun/shelf_virtual_directory/issues/4) by [@YeungKC](https://github.com/YeungKC)

## 1.0.0+1

- updated README.md

## 1.0.0

- Initial Release
