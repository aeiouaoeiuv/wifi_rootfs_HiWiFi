// Some general UI pack related JS
$(function(){
    var __default__options = {
        errorClass:'error'
    };
    /*设置报错状态*/
    function setState($ele,text,options){
        var errorBox = '<div class="J_error errorBox">'+text+'</div>';
        //$ele.next('.errorBox').remove()
        $ele.addClass(options.errorClass)
    }
    /*取消报错状态*/
    function resetState($ele,options){
        $ele.removeClass(options.errorClass)
        $ele.addClass(options.successClass)
    }
    $.fn.extend({
        'ipCheck':function(options){
            options = $.extend({}, __default__options, options);
            var $input = $(this);
            $input.each(function(){
                var $this=$(this),
                    val = $this.val().replace(/^[\s]+/g,''),
                    blank = $this.attr('blank'),
                    errorText = $this.attr('errorText'),
                    blankText = $this.attr('blankText');
                if(blank && val == ''){
                    resetState($this,options)
                    return
                }else if(val == ''){
                    //$this.addClass('error')
                    setState($this,blankText,options)
                    return
                }
                if(!ipRegCheck(val,blank)){
                    //$this.addClass('error')
                    setState($this,errorText,options)
                }else{
                    //$this.removeClass('error')
                    resetState($this,options)
                }
            });
            function ipRegCheck(val,blank){
                var ipReg = /^((2[0-4]\d|25[0-5]|1?\d?\d)\.){3}(2[0-4]\d|25[0-5]|1?\d?\d)$/;
                return ipReg.test(val)
            }

        },
        'lengthCheck':function(options){
            options = $.extend({}, __default__options, options);
            var $this = $(this),
                val =$this.val().replace(/\s+/g,''),
                max =$this.attr('maxLength'),
                min =$this.attr('minLength'),
                blank = $this.attr('blank'),
                errorText = $this.attr('errorText');
            $this.each(function(){
                lengthcheck();
                $this.focus(function(){
                    resetState($this,options)
                })
            })
            function lengthcheck(){
                if(blank=='true' && val == ''){
                    resetState($this,options)
                }else if(val.length < min || val.length > max){
                    setState($this,errorText,options)
                    return false
                }else{
                    return true
                }
            }
        }
    })
})

$(function () {
    // Custom selects
    if($('#s1').length){
        $("#s1").dropkick();
    }
function refreshSelect(){
    var rssi = [],
        rssia=[],
        pw =[];
    $('#s2').find('option').each(function(){
        rssi.push($(this).attr('rssi'))
        pw.push($(this).attr('pw'))
    });
    $.each(rssi,function(){
        rssia.push('wifi rssi'+this)
    });
    if($("#s2").length){
        $("#s2").dropkick({'rssi':rssia,'pw':'lock'});
    }
}
    if(typeof(refresh_aplist)=="function"){
        refresh_aplist(function(){
            refreshSelect()
        })
    $("#refresh_ap_list").click(function(){
        refresh_aplist(function(){
            refreshSelect()
        })
    });
    }
    /*contact*/
    $('.J_more').click(function(e){
        e.preventDefault();
        var $this = $(this);
        if($this.hasClass('close')){
            $('.J_list li').slice(3).nextAll().fadeOut();
            $(this).addClass('open').removeClass('close').text('更多')
        }else{
            $('.J_list li').slice(3).nextAll().fadeIn();
            $(this).addClass('close').removeClass('open').text('收起')
        }
    })
    /*ip*/
    formInit()  //ip
    $('.J_submit').click(function(){
        $('.J_check').ipCheck({'errorClass':'input-error','successClass':'input-success'})
    });
    $('.J_check').focus(function(){
        var top =$(this).offset().top-20;
        $(window).scrollTop(top)
    })
    function formInit(){
        var ipText1='请输入IP地址',
            ipText2 = 'IP地址格式不正确',
            zwText1 = '请输入子网掩码',
            zwText2 = '子网掩码格式不正确',
            wgText1 = '请输入网关',
            wgText2 = '网关格式不正确',
            dnsText1 = '请输入DNS',
            dnsText2 = 'DNS格式不正确';
        var inputTemp = '<input type="text" class="txt radius J_check J_IP" autocomplete="off" placeholder="IP地址：0.0.0.0" blankText="'+ipText1+'" errorText="'+ipText2+'" name=\"static_ip\" >' +
            '<input type="text" class="txt radius J_check J_subnet" autocomplete="off"  placeholder="255.255.255.0" value="255.255.255.0" blankText="'+zwText1+'" errorText="'+zwText2+'" name=\"static_mask\">' +
            '<input type="text" class="txt radius J_check J_gateway" autocomplete="off"  placeholder="网关：0.0.0.0" blankText="'+wgText1+'" errorText="'+wgText2+'" name=\"static_gw\">' +
            '<input type="text" class="txt radius J_check" autocomplete="off"  placeholder="首选DNS：0.0.0.0" blankText="'+dnsText1+'" errorText="'+dnsText2+'" name=\"static_dns\">' +
            '<input type="text" class="txt radius J_check" autocomplete="off"  placeholder="备用DNS：0.0.0.0" blank="true" blankText="'+dnsText1+'" errorText="'+dnsText2+'" name=\"static_dns2\">';
        var aa = userAgentCheck();
        $('#form-box').append(inputTemp)
        $('.J_check').blur(function(){
            $(this).ipCheck({'errorClass':'input-error'})
        });
        $('.J_check').focus(function(){
            $(this).next('.errorBox').remove()
        });
        switch(aa){
            case "Android":
                $('#content').css({'padding-bottom':300+'px'})
                $('#header').hide();
                break;
            case "iPhone":
            case "iPod":
                $('#header').hide();
                break;
        }
        /*gateway auto complete*/
        $('.J_IP,.J_subnet').keyup(function(){
            var gateArray = gatewayCalculate(),
                writeVal = gateArray.join('.');
            $('.J_gateway').val(writeVal);
        });
        function gatewayCalculate (){
            var subnetVal =$('.J_subnet').val().split('.'),
                ipVal = $('.J_IP').val().split('.'),
                gatewayVal=[];
            $.each(subnetVal,function(i,v){
                if(v == '255'){
                    gatewayVal.push(ipVal[i])
                }
            });
            if(gatewayVal.length<4){
                gatewayVal.push('')
            }
            return gatewayVal;
        }
    }
    function userAgentCheck(){
        var userAgentInfo = navigator.userAgent;
        var Agents = new Array("Android", "iPhone", "SymbianOS", "Windows Phone", "iPad", "iPod");
        var flag;
        for (var v = 0; v < Agents.length; v++) {
            if (userAgentInfo.indexOf(Agents[v]) > 0) {
                flag = Agents[v]
                break;
            }
        }
        return flag;
    }
/*修改密码*/
    $('.J_pw').blur(function(){
        $(this).lengthCheck({'blurCheck':true,'errorClass':'input-error'})
    })
});



