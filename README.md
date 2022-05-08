
## Adding Custom Patterns
If a code for a service you use isn't automatically detected with the built-in pattern matchers, you can create a PR to add a custom pattern. In `AppConfig.json`, there is a key called `customPatterns`. A `customPatterns` object must be in the format:
```
{
  "serviceName": "the name of the service that uses this format",
  "matcherPattern": "a regex pattern to determine if a text belongs to this service",
  "codeExtractorPattern": "a regex pattern used to match the OTP code from a message"
}
``` 

For example, if a service sent a text that looked like:
```
someweird-pattern:a1b2c3
```

where `a1b2c3` is the code we want to be parsed, we could an entry that looks like:
```
{
  "serviceName": "some service",
  "matcherPattern": "^someweird-.+$",
  "codeExtractorPattern": "^someweird.+:((\\d|\\D){4,6})$"
}
```
