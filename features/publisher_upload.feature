Feature: Files uploaded by publishers are flagged for processing as soon as possible
	As a publisher
	I want to have my book's (meta)data updated immediately
	So that any incorrect data is corrected as soon as possible

	Background:
		Given there is a publisher called "hachette_uk"

	Scenario Outline: Delivered valid files are flagged for processing
		Given the following file is uploaded:
			| filename   | folder      | permissions |
			| <filename> | hachette_uk | 0664        |
		When it is found by the watcher
		Then its permissions are changed to 0444
		And the following message is posted to the "<queue>" queue:
			| publisher   | uri                     | isbn   |
			| hachette_uk | /hachette_uk/<filename> | <isbn> |

	Examples:
		| filename           | queue                     | isbn          |
		| some_onix.xml      | Ingestion.OnixFileChange  |               |
		| 9780330513081.jpg  | Ingestion.CoverFileChange | 9780330513081 |
		| 9780330513081.epub | Ingestion.EpubFileChange  | 9780330513081 |
