var fs = require('fs');
var exec = require('child_process').exec;

var watchPattern = /^.*\.v$/
fs.watch('.', function(event, fileName){
    if(watchPattern.test(fileName)){
        console.log(new Date());
        console.log('File "' + fileName + '" changed.');
        var child = exec('make test', function(err, stdout, stderr){
            if(err){
                console.error('ERROR: ' + err);
            } else{
                console.error(stderr);
                console.log(stdout);
            }
        });
    }
});
