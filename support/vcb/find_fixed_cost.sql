CREATE OR REPLACE FUNCTION CB_FIND_MATCHING_FIXED_COST(f_vcpu_allocation in number, f_mem_allocation in real, f_cost_matrix_id in integer)
RETURN integer is r_fc_id integer;
v_vcpu_count integer;
v_memory_mb number(19,4);
v_fixed_cost_id integer;
CURSOR fc_cursor is select vcpu_count, memory_mb, fixed_cost_id from cb_vmi_cost_vector where cost_matrix_id = f_cost_matrix_id order by vcpu_count, memory_mb;
BEGIN

  OPEN fc_cursor;
  FETCH fc_cursor INTO v_vcpu_count, v_memory_mb, v_fixed_cost_id;
  WHILE fc_cursor%FOUND
  LOOP
    IF v_vcpu_count < f_vcpu_allocation THEN
      FETCH fc_cursor INTO v_vcpu_count, v_memory_mb, v_fixed_cost_id;
      CONTINUE;
    END IF;
    IF (v_memory_mb/1024) < f_mem_allocation THEN
      FETCH fc_cursor INTO v_vcpu_count, v_memory_mb, v_fixed_cost_id;
      CONTINUE;
    END IF;    
    RETURN v_fixed_cost_id;
  END LOOP;
  CLOSE fc_cursor;
  select default_fixed_cost_id into v_fixed_cost_id from cb_vmi_cost_matrix where cost_matrix_id = f_cost_matrix_id;
  RETURN v_fixed_cost_id;
  EXCEPTION
    WHEN OTHERS THEN
    RETURN -1;
END FIND_MATCHING_FIXED_COST;
/

DECLARE
v_mem_res_id integer;
v_vcpu_res_id integer;
v_entity_id integer;
v_vcpu_allocation number(19,4);
v_vcpu_start_time timestamp(6);
v_vcpu_end_time timestamp(6);
v_mem_allocation number(19,4);
v_mem_start_time timestamp(6);
v_mem_end_time timestamp(6);
v_fc_start_time timestamp(6);
v_fc_end_time timestamp(6);
v_cost_model_id integer;
v_cost_matrix_id integer;
v_fc_id integer;

CURSOR entity_cursor is (select che.cb_hierarchical_entity_id
from cb_hierarchy_relation chr 
     inner join cb_hierarchical_entity che on chr.entity_id = che.cb_hierarchical_entity_id
     inner join cb_entity ce on che.entity_id = ce.entity_id
where chr.start_time > to_date('20110728', 'yyyymmdd') and chr.start_time < to_date('20111007', 'yyyymmdd') 
      and chr.end_time is not null
      and ce.entity_type_id = 0);
CURSOR allocation_cursor is select allocation_value, start_time, end_time from cb_entity_resource_allocation where computing_resource_id = v_vcpu_res_id and entity_id = v_entity_id order by start_time;
CURSOR mem_allocation_cursor is select allocation_value, start_time, end_time from cb_entity_resource_allocation where computing_resource_id = v_mem_res_id and entity_id = v_entity_id order by start_time;
BEGIN

    -- VM Instance fixed cost is configured only for two cost models (select * from cb_vmi_cm_matrix_map) i.e 1433 and 2237, run this procedure for each cost model
    v_cost_model_id := 1433;
    select cost_matrix_id into v_cost_matrix_id from cb_vmi_cm_matrix_map where cost_model_id = v_cost_model_id;
    dbms_output.enable(1000000);
    v_mem_res_id := 5;
    v_vcpu_res_id := 10;
    OPEN entity_cursor;
    FETCH entity_cursor INTO v_entity_id;
    WHILE entity_cursor%FOUND
    LOOP
    
      OPEN allocation_cursor;
      FETCH allocation_cursor INTO v_vcpu_allocation, v_vcpu_start_time, v_vcpu_end_time;

      OPEN mem_allocation_cursor;
      FETCH mem_allocation_cursor INTO v_mem_allocation, v_mem_start_time, v_mem_end_time;

      WHILE allocation_cursor%FOUND and mem_allocation_cursor%FOUND
      LOOP

        -- v_fc_start_time := max(v_vcpu_start_time, v_mem_start_time);
        IF v_vcpu_start_time > v_mem_start_time THEN v_fc_start_time:=v_vcpu_start_time; ELSE v_fc_start_time:=v_mem_start_time; END IF;
           
        -- v_fc_end_time := min(v_vcpu_end_time, v_mem_end_time);
        IF v_vcpu_end_time > v_mem_end_time THEN v_fc_end_time:=v_mem_end_time; ELSE v_fc_end_time:=v_vcpu_end_time; END IF;

        -- If there is a overlap, valid interval process it
        IF v_fc_start_time < v_fc_end_time THEN
          select CB_FIND_MATCHING_FIXED_COST(v_vcpu_allocation, v_mem_allocation, v_cost_matrix_id) into v_fc_id from dual;
          dbms_output.put_line('costModelId=' || v_cost_model_id || ', fixed_cost_id=' || v_fc_id || ', id=' || v_entity_id || ', vcpu=' || v_vcpu_allocation || ', mem=' || v_mem_allocation || ', st=' || v_fc_start_time || ', et=' || v_fc_end_time);
        END IF;
        
        IF v_vcpu_end_time < v_mem_end_time THEN 
           FETCH allocation_cursor INTO v_vcpu_allocation, v_vcpu_start_time, v_vcpu_end_time;
        ELSIF v_mem_end_time < v_vcpu_end_time THEN
           FETCH mem_allocation_cursor INTO v_mem_allocation, v_mem_start_time, v_mem_end_time;
        ELSE
           FETCH allocation_cursor INTO v_vcpu_allocation, v_vcpu_start_time, v_vcpu_end_time;
           FETCH mem_allocation_cursor INTO v_mem_allocation, v_mem_start_time, v_mem_end_time;
        END IF;

      END LOOP;
      CLOSE allocation_cursor;
      CLOSE mem_allocation_cursor;      
    FETCH entity_cursor INTO v_entity_id;
    END LOOP;
    CLOSE entity_cursor;
EXCEPTION
    WHEN OTHERS THEN
    IF entity_cursor%ISOPEN THEN CLOSE entity_cursor; END IF;
    IF allocation_cursor%ISOPEN THEN CLOSE allocation_cursor; END IF;
    IF mem_allocation_cursor%ISOPEN THEN CLOSE mem_allocation_cursor; END IF;
    RAISE;
END;
