create or replace PROCEDURE                                                                                                             carga_cabecera_djib_incre

   IS

v_fecha_vencimiento date;
v_fecha_presentacion date;
 v_count          NUMBER := 0;
    v_long_fact      NUMBER := 0;
    v_error          VARCHAR (120);
    v_impuesto number(15,2);
    v_existe number;
       CURSOR resumen
    IS
        SELECT   pa_funciones_generales.get_cuit(v.contribuyente) as cuit,
                 v.anio,
                 v.numero_cuota,
                 v.numero_rectificativa,
                 v.numero_obligacion_impuesto,
                 pa_funciones_generales.convierte_a_numero_prueba(d1.col01) total,
                 pa_funciones_generales.convierte_a_numero_prueba (d1.col02) saldo_afavor_ant,
                 pa_funciones_generales.convierte_a_numero_prueba(d1.col03) pagos_cta,
                 pa_funciones_generales.convierte_a_numero_prueba (d1.col04) retenciones,
                 pa_funciones_generales.convierte_a_numero_prueba (d1.col05) percepciones,
                 pa_funciones_generales.convierte_a_numero_prueba(d1.col06) per_banc,
                 pa_funciones_generales.convierte_a_numero_prueba (d1.col08) sindesc,
                 pa_funciones_generales.convierte_a_numero_prueba (d1.col11) favor_contr,
                 pa_funciones_generales.convierte_a_numero_prueba(d1.col12) favor_dgr,
                  pa_funciones_generales.convierte_a_numero_prueba(d1.col03) pagos_cuenta,
                 pa_funciones_generales.convierte_a_numero_prueba(d1.col08) descuento
          FROM   tbl_vencimientos@tcsdisc v,
          tbl_detalles_ddjj@tcsdisc d1,
          ddjj_para_procesar@tcsprod f
            WHERE   v.impuesto = d1.impuesto(+)
                 AND v.concepto_obligacion = d1.concepto_obligacion(+)
                 AND v.numero_obligacion_impuesto = d1.numero_obligacion_impuesto(+)
                 AND v.numero_cuota = d1.numero_cuota(+)
                 AND v.numero_rectificativa = d1.numero_rectificativa(+)
                 AND d1.tipo_detalle_dj(+) = '0013'
                 AND v.formulario IN ('0002', '0015')
                 AND v.impuesto = f.impuesto
                 AND v.concepto_obligacion = f.concepto_obligacion
                 and v.numero_obligacion_impuesto=f.numero_obligacion_impuesto
                 and v.anio=f.anio
                 and v.numero_cuota=f.numero_cuota
                 and v.numero_rectificativa=f.numero_rectificativa
                 and f.procesada ='C' and v.anio>2024 and v.numero_cuota>=1 ;--in ('C','N');


BEGIN











 FOR i IN resumen  LOOP

 BEGIN
 v_existe:=0;
select count(0) into v_existe from cabecera_dj where cuit=i.cuit and anio=i.anio and numero_obligacion_impuesto=i.numero_obligacion_impuesto and numero_cuota=i.numero_cuota and numero_rectificativa=i.numero_rectificativa;
if v_existe>0 then
delete cabecera_dj where cuit=i.cuit and anio=i.anio  and numero_obligacion_impuesto=i.numero_obligacion_impuesto and numero_cuota=i.numero_cuota and numero_rectificativa=i.numero_rectificativa and tipo_contri='Directo';
commit;
end if;


insert into cabecera_dj
values
(
'Directo',i.cuit,(select razon_social||' '||nombre from vw_tbl_personas where cuit= i.cuit),
i.anio||lpad(i.numero_cuota,2,'0'),
to_date(i.anio||lpad(i.numero_cuota,2,'0')||'01','YYYYMMDD'),
 i.anio, i.numero_cuota,       0, 0, 0,
       0,0,0,0,0,0,0,
       0,0,0,0,0,0,0,0,
       i.numero_rectificativa,null,null,null,null,null,i.numero_obligacion_impuesto,0,0,0,0,'I'
);

commit;





begin
 v_fecha_vencimiento:=null;
 select  distinct(fecha_primer_vencimiento) into v_fecha_vencimiento
from tbl_vencimientos@tcsdisc.dgrcorrientes.gov.ar c
where
--c.clave_imponible=   tcscorrientes.pa_imponible.get_clave_imponible@tcsprod.dgrcorrientes.gov.ar('0001', i.cuit, null,null,null, null) and
 c.impuesto='0035'
and c.concepto_obligacion='0017'
and c.numero_obligacion_impuesto=i.numero_obligacion_impuesto
and c.anio=i.anio
and c.numero_cuota=i.numero_cuota
and numero_rectificativa=0;
exception
when others then
v_fecha_vencimiento:=null;
end;

v_fecha_presentacion:=null;
 select  distinct(fecha_presentacion) into v_fecha_presentacion
from tbl_vencimientos@tcsdisc c
where  c.impuesto='0035'
and c.concepto_obligacion='0017'
and c.numero_obligacion_impuesto=i.numero_obligacion_impuesto
and c.anio=i.anio
and c.numero_cuota=i.numero_cuota
and c.numero_rectificativa=i.numero_rectificativa;

v_impuesto:=0;
select sum(impuesto) into v_impuesto
from detalle_dj
where  cuit = i.cuit
                     AND anio = i.anio
                     AND numero_cuota = i.numero_cuota
                     and numero_rectificativa=i.numero_rectificativa
                     and tipo_contrib='Directo';


         UPDATE   cabecera_dj
               SET   impuesto_determinado = v_impuesto,
                     saldo_favor = i.saldo_afavor_ant,
                     retenciones = i.retenciones,
                     percepciones_soportadas = i.percepciones,
                     retenciones_bancarias = i.per_banc,
                     creditos_anticipo = i.pagos_cta,
                     diferencia_favor_contri = i.favor_contr,
                     diferencia_favor_fisco = i.favor_dgr,
                     fecha_vencimiento=v_fecha_vencimiento,
                     fecha_presentacion=v_fecha_presentacion,
                     PAGOS_A_CUENTA=I.pagos_cuenta,
                     descuento=i.descuento


             WHERE       cuit = i.cuit
                     AND anio = i.anio
                     AND numero_cuota = i.numero_cuota
                     and numero_rectificativa=i.numero_rectificativa
                     and numero_obligacion_impuesto=i.numero_obligacion_impuesto
                     and tipo_contri='Directo';


            COMMIT;

   update cabecera_dj a
set ultima_presentacion=
decode(((
(SELECT COUNT(0) FROM cabecera_dj B WHERE A.CUIT=B.CUIT AND A.ANTICIPO=B.ANTICIPO)
-1)
-a.numero_rectificativa),'0','S','N')
where cuit=i.cuit
and anticipo=i.anio||lpad(i.numero_cuota,2,'0')
and tipo_contri='Directo';
commit;

update ddjj_para_procesar@tcsprod.dgrcorrientes.gov.ar
set procesada='S',fecha_proceso=sysdate
where  impuesto='0035'
and concepto_obligacion='0017'
AND anio = i.anio
AND numero_cuota = i.numero_cuota
and numero_rectificativa=i.numero_rectificativa
and numero_obligacion_impuesto=i.numero_obligacion_impuesto

;

commit;






        EXCEPTION
            WHEN OTHERS  THEN
                ROLLBACK;
                DBMS_OUTPUT.put_line (SQLERRM);
        END;
    END LOOP;



EXCEPTION
    WHEN others THEN
dbms_output.put_line(sqlerrm);
END;