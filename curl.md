Hi John.

You're gonna have to stomach some of this scripting stuff if you want to run the curl, but I think the stuff you wanted to compare against is in the signer.sh file.

That being said, to get it to run, do the following:
*(assumes your bucket is "jaydub-s3-object-lambda-s3bucket-15j6ame50rl1h", and the object you want is "2.jpg")*

```
cd docker
sh signer.sh \
  task=curl \
  profile=[your profile] \
  object_key=2.jpg
```

