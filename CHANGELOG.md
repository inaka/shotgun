# Change Log

## [0.1.15](https://github.com/inaka/shotgun/tree/0.1.15) (2016-01-05)
[Full Changelog](https://github.com/inaka/shotgun/compare/0.1.12...0.1.15)

**Implemented enhancements:**

- URI handling: gun and cowlib handle iodata, but shotgun only handles string [\#104](https://github.com/inaka/shotgun/issues/104)
- Verify the uri provided conforms to the HTTP Request specs  [\#101](https://github.com/inaka/shotgun/issues/101)
- Add tests [\#98](https://github.com/inaka/shotgun/issues/98)
- Show more descriptive errors when asking for events but there is no connection [\#95](https://github.com/inaka/shotgun/issues/95)

**Fixed bugs:**

- call to undefined function shotgun:wait\_response/3 [\#134](https://github.com/inaka/shotgun/issues/134)
- Fix return type in spec of parse\_event/1 function [\#107](https://github.com/inaka/shotgun/issues/107)
- Fix the options type and docs where it says async\_data instead of async\_mode [\#106](https://github.com/inaka/shotgun/issues/106)
- encode\_basic\_auth\(\[\], \[\]\) returns \[\], but the value is used to create binary. [\#103](https://github.com/inaka/shotgun/issues/103)
- Crash when fetching from slow HTTP server: shotgun:wait\_response/3 not exported [\#96](https://github.com/inaka/shotgun/issues/96)
- Add last\_event\_id per SSE specification [\#45](https://github.com/inaka/shotgun/issues/45)

**Closed issues:**

- Support headers as proplists [\#125](https://github.com/inaka/shotgun/issues/125)
- Allow making chunked requests [\#118](https://github.com/inaka/shotgun/issues/118)
- Does sse\_events correctly detect the end of an SSE event? [\#114](https://github.com/inaka/shotgun/issues/114)
- Change the `data` key for the `event\(\)` from `\[binary\(\)\]` to `binary\(\)`  [\#110](https://github.com/inaka/shotgun/issues/110)
- Queue operations into gun [\#21](https://github.com/inaka/shotgun/issues/21)

**Merged pull requests:**

- \[\#122\] Updated to upload in hex.pm [\#135](https://github.com/inaka/shotgun/pull/135) ([davecaos](https://github.com/davecaos))
- \[\#102\] Allow proplist headers [\#133](https://github.com/inaka/shotgun/pull/133) ([tothlac](https://github.com/tothlac))
- \[Closes \#98\] Added tests and improved code [\#131](https://github.com/inaka/shotgun/pull/131) ([jfacorro](https://github.com/jfacorro))
- Revert "\(\#45\) Add last\_event\_id per sse spec" [\#129](https://github.com/inaka/shotgun/pull/129) ([elbrujohalcon](https://github.com/elbrujohalcon))
- \(\#45\) Add last\_event\_id per sse spec [\#128](https://github.com/inaka/shotgun/pull/128) ([tothlac](https://github.com/tothlac))
- Dialyzer fixes and firx for encode basic auth [\#126](https://github.com/inaka/shotgun/pull/126) ([tothlac](https://github.com/tothlac))
- \[Close \#118\] Chunked requests [\#119](https://github.com/inaka/shotgun/pull/119) ([jfacorro](https://github.com/jfacorro))
- Maybe issue 95 fix [\#115](https://github.com/inaka/shotgun/pull/115) ([kennethlakin](https://github.com/kennethlakin))
- \[\#110\] Return data as a binary [\#112](https://github.com/inaka/shotgun/pull/112) ([jfacorro](https://github.com/jfacorro))
- \[Closes \#107\]\[Closes \#106\] Fix parse event spec [\#108](https://github.com/inaka/shotgun/pull/108) ([jfacorro](https://github.com/jfacorro))
- Make shotgun handle iodata\(\) URIs [\#105](https://github.com/inaka/shotgun/pull/105) ([kennethlakin](https://github.com/kennethlakin))
- shotgun FSM fixes [\#100](https://github.com/inaka/shotgun/pull/100) ([kennethlakin](https://github.com/kennethlakin))
- Replace shogtun with shotgun. [\#97](https://github.com/inaka/shotgun/pull/97) ([rmoorman](https://github.com/rmoorman))
- Error reply [\#90](https://github.com/inaka/shotgun/pull/90) ([davecaos](https://github.com/davecaos))

## [0.1.12](https://github.com/inaka/shotgun/tree/0.1.12) (2015-06-26)
[Full Changelog](https://github.com/inaka/shotgun/compare/0.1.11...0.1.12)

**Fixed bugs:**

- Shotgun supervisor does not realize children die [\#70](https://github.com/inaka/shotgun/issues/70)

**Closed issues:**

- Version bump 0.1.12 [\#93](https://github.com/inaka/shotgun/issues/93)
- SSE Comments are unrecognised [\#88](https://github.com/inaka/shotgun/issues/88)

**Merged pull requests:**

- \[Closes \#93\] Version bump to 0.1.12 [\#94](https://github.com/inaka/shotgun/pull/94) ([jfacorro](https://github.com/jfacorro))
- \[\#70\] Terminate child so that it is not listed as a worker [\#92](https://github.com/inaka/shotgun/pull/92) ([jfacorro](https://github.com/jfacorro))
- Updated license [\#91](https://github.com/inaka/shotgun/pull/91) ([spike886](https://github.com/spike886))
- \[\#88\] fix unrecognised events in parse\_event\(\) [\#89](https://github.com/inaka/shotgun/pull/89) ([davecaos](https://github.com/davecaos))

## [0.1.11](https://github.com/inaka/shotgun/tree/0.1.11) (2015-06-06)
[Full Changelog](https://github.com/inaka/shotgun/compare/0.1.10...0.1.11)

**Closed issues:**

- Stop using master branch for 'gun' dependency [\#67](https://github.com/inaka/shotgun/issues/67)

**Merged pull requests:**

- Version Bump to 0.1.11 [\#87](https://github.com/inaka/shotgun/pull/87) ([elbrujohalcon](https://github.com/elbrujohalcon))
- Update dependencies [\#69](https://github.com/inaka/shotgun/pull/69) ([elbrujohalcon](https://github.com/elbrujohalcon))

## [0.1.10](https://github.com/inaka/shotgun/tree/0.1.10) (2015-05-19)
[Full Changelog](https://github.com/inaka/shotgun/compare/0.1.9...0.1.10)

**Closed issues:**

- Version Bump to 0.1.10 [\#85](https://github.com/inaka/shotgun/issues/85)
- Update rebar.config file [\#83](https://github.com/inaka/shotgun/issues/83)

**Merged pull requests:**

- \[Fix \#85\] Version bump to 0.1.10 [\#86](https://github.com/inaka/shotgun/pull/86) ([davecaos](https://github.com/davecaos))
- \[fix \#83\] Update Gun dependency to 1.0.0-pre.1 [\#84](https://github.com/inaka/shotgun/pull/84) ([davecaos](https://github.com/davecaos))
- \[Fix \#80\] Version Bump 0.1.9 [\#82](https://github.com/inaka/shotgun/pull/82) ([davecaos](https://github.com/davecaos))

## [0.1.9](https://github.com/inaka/shotgun/tree/0.1.9) (2015-05-19)
[Full Changelog](https://github.com/inaka/shotgun/compare/0.1.8...0.1.9)

**Fixed bugs:**

- Change shotgun version [\#71](https://github.com/inaka/shotgun/issues/71)

**Closed issues:**

- Update Gun dependencies [\#80](https://github.com/inaka/shotgun/issues/80)
- Remove lager as a dependency since it is not used anywhere [\#76](https://github.com/inaka/shotgun/issues/76)
- Remove shotgun:maps\_get/3 and just use maps:get/3 [\#74](https://github.com/inaka/shotgun/issues/74)
- Update gun version to 1.0.0-pre.1 [\#73](https://github.com/inaka/shotgun/issues/73)

**Merged pull requests:**

- \[Fix \#80\] Gun dependencies updated to 1.0.0-pre.1 [\#81](https://github.com/inaka/shotgun/pull/81) ([davecaos](https://github.com/davecaos))
- \[\#73\] Update gun version, in rebar.config as well [\#79](https://github.com/inaka/shotgun/pull/79) ([jfacorro](https://github.com/jfacorro))
- \[Closes \#73\] Update gun version [\#78](https://github.com/inaka/shotgun/pull/78) ([jfacorro](https://github.com/jfacorro))
- \[Closes \#76\] Remove lager dep [\#77](https://github.com/inaka/shotgun/pull/77) ([jfacorro](https://github.com/jfacorro))
- \[Closes \#74\] Deleted function and used maps:get/3 [\#75](https://github.com/inaka/shotgun/pull/75) ([jfacorro](https://github.com/jfacorro))
- Update LICENSE [\#72](https://github.com/inaka/shotgun/pull/72) ([andresinaka](https://github.com/andresinaka))

## [0.1.8](https://github.com/inaka/shotgun/tree/0.1.8) (2015-04-10)
[Full Changelog](https://github.com/inaka/shotgun/compare/0.1.7...0.1.8)

**Merged pull requests:**

- Make it compatible with latest release of 'gun' [\#68](https://github.com/inaka/shotgun/pull/68) ([cabol](https://github.com/cabol))

## [0.1.7](https://github.com/inaka/shotgun/tree/0.1.7) (2015-03-05)
[Full Changelog](https://github.com/inaka/shotgun/compare/0.1.6...0.1.7)

**Implemented enhancements:**

- Use inaka's sync with tag 0.1 [\#65](https://github.com/inaka/shotgun/issues/65)
- Add documentation for SSL support in README [\#52](https://github.com/inaka/shotgun/issues/52)
- Convert headers in response to a map [\#46](https://github.com/inaka/shotgun/issues/46)

**Fixed bugs:**

- Don't rely only on transfer-encoding header value to check for chunk response [\#54](https://github.com/inaka/shotgun/issues/54)
- `fin` data chunks are not added in the events queue  [\#58](https://github.com/inaka/shotgun/issues/58)

**Closed issues:**

- Removing sync from dependencies? [\#63](https://github.com/inaka/shotgun/issues/63)
- shotgun fails to compile on 0.1.6 and fbe44e2 using R16B03 [\#60](https://github.com/inaka/shotgun/issues/60)
- Test non SSE chunked streams [\#15](https://github.com/inaka/shotgun/issues/15)

**Merged pull requests:**

- \[Closes \#65\] Use inaka's sync fork. Specify commit id for gun. Update elvis.config. [\#66](https://github.com/inaka/shotgun/pull/66) ([jfacorro](https://github.com/jfacorro))
- Remove Sync as dependency [\#64](https://github.com/inaka/shotgun/pull/64) ([sata](https://github.com/sata))
- Fixed rebar.config dependencies syntax so they don't require github acco... [\#62](https://github.com/inaka/shotgun/pull/62) ([GuidoRumi](https://github.com/GuidoRumi))
- \[\#60\] Added minimum erlang version required to README [\#61](https://github.com/inaka/shotgun/pull/61) ([igaray](https://github.com/igaray))
- \[Fixes \#58\] Detect fin, go to at\_rest state and add event. [\#59](https://github.com/inaka/shotgun/pull/59) ([jfacorro](https://github.com/jfacorro))
- \[Closes \#52\] Added HTTP secure section to readme. [\#57](https://github.com/inaka/shotgun/pull/57) ([jfacorro](https://github.com/jfacorro))
- Request timeout. [\#56](https://github.com/inaka/shotgun/pull/56) ([loguntsov](https://github.com/loguntsov))

## [0.1.6](https://github.com/inaka/shotgun/tree/0.1.6) (2014-12-02)
[Full Changelog](https://github.com/inaka/shotgun/compare/0.1.5...0.1.6)

**Fixed bugs:**

- async\_mode instead of chunk\_mode [\#53](https://github.com/inaka/shotgun/issues/53)

**Merged pull requests:**

- \[Fixes \#53 \#54\]. [\#55](https://github.com/inaka/shotgun/pull/55) ([Euen](https://github.com/Euen))

## [0.1.5](https://github.com/inaka/shotgun/tree/0.1.5) (2014-10-30)
[Full Changelog](https://github.com/inaka/shotgun/compare/0.1.4...0.1.5)

**Implemented enhancements:**

- Update to erlang.mk v1 [\#31](https://github.com/inaka/shotgun/issues/31)
- SSL support [\#41](https://github.com/inaka/shotgun/issues/41)
- Warn user about missing slash when using the verb functions [\#33](https://github.com/inaka/shotgun/issues/33)

**Fixed bugs:**

- SSE and Server Errors [\#36](https://github.com/inaka/shotgun/issues/36)

**Closed issues:**

- binary headers? [\#49](https://github.com/inaka/shotgun/issues/49)
- Fulfill the open-source checklist [\#32](https://github.com/inaka/shotgun/issues/32)

**Merged pull requests:**

- \[Closes \#36\] Return the server response when a chunked connection cannot be established [\#51](https://github.com/inaka/shotgun/pull/51) ([jfacorro](https://github.com/jfacorro))
- \[Closes \#33\] Throw error for missing leading slash [\#50](https://github.com/inaka/shotgun/pull/50) ([jfacorro](https://github.com/jfacorro))
- \[Closes \#41\] Added support for SSL [\#48](https://github.com/inaka/shotgun/pull/48) ([jfacorro](https://github.com/jfacorro))
- \[Closes \#31\] Updated erlang.mk to 1.1.0 [\#47](https://github.com/inaka/shotgun/pull/47) ([jfacorro](https://github.com/jfacorro))
- \[\#32\] Added doc strings to functions. [\#44](https://github.com/inaka/shotgun/pull/44) ([jfacorro](https://github.com/jfacorro))
- \[\#32\] Useful README. [\#42](https://github.com/inaka/shotgun/pull/42) ([jfacorro](https://github.com/jfacorro))

## [0.1.4](https://github.com/inaka/shotgun/tree/0.1.4) (2014-10-14)
[Full Changelog](https://github.com/inaka/shotgun/compare/0.1.3...0.1.4)

**Closed issues:**

- Allow to specify a body for all HTTP methods or... [\#39](https://github.com/inaka/shotgun/issues/39)

**Merged pull requests:**

- \[Closes \#39\] Added request/6. [\#40](https://github.com/inaka/shotgun/pull/40) ([jfacorro](https://github.com/jfacorro))

## [0.1.3](https://github.com/inaka/shotgun/tree/0.1.3) (2014-10-14)
[Full Changelog](https://github.com/inaka/shotgun/compare/0.1.2...0.1.3)

**Implemented enhancements:**

- Add rebar.config [\#37](https://github.com/inaka/shotgun/issues/37)

**Merged pull requests:**

- \[Closes \#37\] Added rebar.config. [\#38](https://github.com/inaka/shotgun/pull/38) ([jfacorro](https://github.com/jfacorro))

## [0.1.2](https://github.com/inaka/shotgun/tree/0.1.2) (2014-09-29)
[Full Changelog](https://github.com/inaka/shotgun/compare/0.1.1...0.1.2)

**Fixed bugs:**

- Add response to events queue on termination of async request. [\#34](https://github.com/inaka/shotgun/issues/34)
- SSE events should be correctly split [\#13](https://github.com/inaka/shotgun/issues/13)

**Merged pull requests:**

- \[Closes \#34\] Added response to events queue on async request termination. [\#35](https://github.com/inaka/shotgun/pull/35) ([Euen](https://github.com/Euen))

## [0.1.1](https://github.com/inaka/shotgun/tree/0.1.1) (2014-09-25)
[Full Changelog](https://github.com/inaka/shotgun/compare/0.1.0...0.1.1)

**Merged pull requests:**

- Split events [\#17](https://github.com/inaka/shotgun/pull/17) ([unbalancedparentheses](https://github.com/unbalancedparentheses))

## [0.1.0](https://github.com/inaka/shotgun/tree/0.1.0) (2014-08-15)
**Implemented enhancements:**

- Add support for pushing messages [\#8](https://github.com/inaka/shotgun/issues/8)
- Add all http verbs [\#5](https://github.com/inaka/shotgun/issues/5)
- basic auth [\#4](https://github.com/inaka/shotgun/issues/4)
- Replace pop by events [\#3](https://github.com/inaka/shotgun/issues/3)

**Fixed bugs:**

- Make shotgun releasable [\#29](https://github.com/inaka/shotgun/issues/29)
- Move basic\_auth from the Options to the Headers argument [\#27](https://github.com/inaka/shotgun/issues/27)
- Don't allow async calls for verbs other than GET [\#25](https://github.com/inaka/shotgun/issues/25)
- Multiple requests on the same connection should work fine [\#19](https://github.com/inaka/shotgun/issues/19)
- Stop should call supervisor terminate child [\#12](https://github.com/inaka/shotgun/issues/12)
- Add supervisor [\#6](https://github.com/inaka/shotgun/issues/6)

**Closed issues:**

- Manage headers as map, not as proplist [\#7](https://github.com/inaka/shotgun/issues/7)
- Add specs [\#2](https://github.com/inaka/shotgun/issues/2)

**Merged pull requests:**

- \[\#29\] Make shotgun releasable. [\#30](https://github.com/inaka/shotgun/pull/30) ([jfacorro](https://github.com/jfacorro))
- \[Closes \#27\] Process basic\_auth on headers, not on options. [\#28](https://github.com/inaka/shotgun/pull/28) ([jfacorro](https://github.com/jfacorro))
- \[Closes \#25\] Throw when async option is used with verbs other than GET. [\#26](https://github.com/inaka/shotgun/pull/26) ([jfacorro](https://github.com/jfacorro))
- \[Closes \#19\] Upon response fin only reply when call is not async. [\#24](https://github.com/inaka/shotgun/pull/24) ([jfacorro](https://github.com/jfacorro))
- \[Closes \#5\] Implemented all http verbs. [\#23](https://github.com/inaka/shotgun/pull/23) ([jfacorro](https://github.com/jfacorro))
- \[Closes \#4\] Added option to specify basic auth credentials. [\#22](https://github.com/inaka/shotgun/pull/22) ([jfacorro](https://github.com/jfacorro))
- \[Closes \#3\] Replaced pop/1 for events/1. [\#20](https://github.com/inaka/shotgun/pull/20) ([jfacorro](https://github.com/jfacorro))
- \[Closes \#2\] Added specs. [\#18](https://github.com/inaka/shotgun/pull/18) ([jfacorro](https://github.com/jfacorro))
- Shotgun headers should be a map now [\#14](https://github.com/inaka/shotgun/pull/14) ([unbalancedparentheses](https://github.com/unbalancedparentheses))
- Added supervisor with strategy simple one for one [\#11](https://github.com/inaka/shotgun/pull/11) ([unbalancedparentheses](https://github.com/unbalancedparentheses))
- Reply with reference so that the client can store it ASAP [\#10](https://github.com/inaka/shotgun/pull/10) ([unbalancedparentheses](https://github.com/unbalancedparentheses))
- Now user can provide a handle\_event  [\#9](https://github.com/inaka/shotgun/pull/9) ([unbalancedparentheses](https://github.com/unbalancedparentheses))
- First commit [\#1](https://github.com/inaka/shotgun/pull/1) ([unbalancedparentheses](https://github.com/unbalancedparentheses))



\* *This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*