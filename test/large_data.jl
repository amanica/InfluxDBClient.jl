@testset "Large Data.jl                  " begin
    create_bucket(isettings,a_random_bucket_name);

    #large_data
    
########################################################################
#without compression
#time to construct lp is NOT linear in nn
########################################################################

    nn = 10_000
    df = generate_data(nn)

    #@btime lp = lineprotocol("my_meas",df,["temperature","an_int_value","abool","humidity"],tags=["color","sensor_id"], :datetime);
    ela = @elapsed lineprotocol("my_meas",df,["temperature","an_int_value","abool","humidity"],tags=["color","sensor_id"], :datetime);
    @test ela < 20
    # 5.5 seconds for 20k rows
    # 1.5 seconds for 10k rows
    # 10ms for 1k rows (not linear at all, damn strings)
    
    lp = lineprotocol("my_meas",df,["temperature","an_int_value","abool","humidity"],tags=["color","sensor_id"], :datetime);
    @time write_data(isettings,a_random_bucket_name,lp,"ns")
    @test length(findall('\n',lp)) == nn - 1 #only works if data has no \n
    
    ########################################################################
    #batch processing data
    ########################################################################
    bs = div(size(df,1),10)
    @test bs > 100
    
    #method errors
    @test_throws MethodError write_dataframe(settXXXXing=isettings,bucket=a_random_bucket_name,measurement="some_measurement",data=df,fields=["temperature","an_int_value","abool","humidity"],:datetime,tags=["color","sensor_id"],batchsize = bs,influx_precision="s",tzstr="Europe/Berlin",compress=false)
    @test_throws MethodError write_dataframe(setting=isettings,bucket=a_random_bucket_name,measurement="some_measurement",data=df,fields=["temperature","an_int_value","abool","humidity"],:datetime,tags=["color","sensor_id"],batchsize = bs,influx_precision="s",tzstr="Europe/Berlin",compress=false)

    #zero rows
    @test_throws ArgumentError write_dataframe(settings=isettings,bucket=a_random_bucket_name,measurement="some_measurement",data=DataFrame(),fields=["temperature","an_int_value","abool","humidity"],timestamp=:datetime,tags=["color","sensor_id"],influx_precision="s",tzstr="Europe/Berlin",compress=false,batchsize = bs);

    #10 batches
    @time rs,lp = write_dataframe(settings=isettings,bucket=a_random_bucket_name,measurement="some_measurement",data=df,fields=["temperature","an_int_value","abool","humidity"],timestamp=:datetime,tags=["color","sensor_id"],influx_precision="s",tzstr="Europe/Berlin",compress=false,batchsize = bs);
    @time rs,lp = write_dataframe(settings=isettings,bucket=a_random_bucket_name,measurement="some_measurement",data=df,fields=["temperature","an_int_value","abool","humidity"],timestamp=:datetime,tags=["color","sensor_id"],influx_precision="s",tzstr="Europe/Berlin",compress=false,batchsize = bs,printinfo=false);
    #no batches
    @time rs,lp = write_dataframe(settings=isettings,bucket=a_random_bucket_name,measurement="some_measurement",data=df,fields=["temperature","an_int_value","abool","humidity"],timestamp=:datetime,tags=["color","sensor_id"],influx_precision="s",tzstr="Europe/Berlin",compress=false,batchsize = 0);

########################################################################
#with compression
#time to construct lp is linear in nn
########################################################################
    nn = 100_000
    df = generate_data(nn)
    
    ela = @elapsed lineprotocol("my_meas",df,["temperature","an_int_value","abool","humidity"],tags=["color","sensor_id"], :datetime,compress = true);
    @test ela < 20
    # 0.3 seconds for 20k rows
    # 0.64 seconds for 40k rows
    # 1.4 seconds for 100k rows
    # 2.84 seconds for 200k rows

    #=
        unc = round(Base.summarysize(lp)/1024/1024,digits=2)
        bdy = CodecZlib.transcode(CodecZlib.GzipCompressor, lp)
        comp = round(Base.summarysize(bdy)/1024/1024,digits=2)
        ratio = comp/unc
    =#

    lp = lineprotocol("my_meas",df,["temperature","an_int_value","abool","humidity"],tags=["color","sensor_id"], :datetime,compress = true);
    @test 204 == write_data(isettings,a_random_bucket_name,lp,"ns")

    #write in batches
    bs = 5_000
    df = generate_data(3 * bs)
    @time rs,lp = write_dataframe(settings=isettings,bucket=a_random_bucket_name,measurement="some_measurement",data=df,fields=["temperature","an_int_value","abool","humidity"],timestamp=:datetime,tags=["color","sensor_id"],influx_precision="s",tzstr="Europe/Berlin",compress=true,batchsize = bs,printinfo=false);
    #@time rs,lp = write_dataframe(settings=isettings,bucket=a_random_bucket_name,measurement="some_measurement",data=df,fields=["temperature","an_int_value","abool","humidity"],timestamp=:datetime,tags=["color","sensor_id"],influx_precision="s",tzstr="Europe/Berlin",compress=false,batchsize = bs,printinfo=false);

    delete_bucket(isettings,a_random_bucket_name);
end