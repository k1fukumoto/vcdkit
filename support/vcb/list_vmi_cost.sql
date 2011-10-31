SET SERVEROUTPUT ON
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

CURSOR allocation_cursor IS
       SELECT allocation_value, start_time, end_time 
       FROM cb_entity_resource_allocation 
       WHERE computing_resource_id = v_vcpu_res_id 
       AND entity_id = v_entity_id 
       ORDER BY start_time;
CURSOR mem_allocation_cursor IS
       SELECT allocation_value, start_time, end_time 
       FROM cb_entity_resource_allocation 
       WHERE computing_resource_id = v_mem_res_id 
       AND entity_id = v_entity_id 
       ORDER BY start_time;

BEGIN
    v_cost_model_id := <%= cmid %>;
    v_entity_id := <%= heid %>;

    select cost_matrix_id into v_cost_matrix_id from cb_vmi_cm_matrix_map where cost_model_id = v_cost_model_id;
    dbms_output.enable(1000000);
    v_mem_res_id := 5;
    v_vcpu_res_id := 10;

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
	--    select CB_FIND_MATCHING_FIXED_COST(v_vcpu_allocation, v_mem_allocation, v_cost_matrix_id) into v_fc_id from dual;
          dbms_output.put_line('costModelId=' || v_cost_model_id || ', id=' || v_entity_id || ', vcpu=' || v_vcpu_allocation || ', mem=' || v_mem_allocation || ', st=' || v_fc_start_time || ', et=' || v_fc_end_time);
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
EXCEPTION
    WHEN OTHERS THEN
    IF allocation_cursor%ISOPEN THEN CLOSE allocation_cursor; END IF;
    IF mem_allocation_cursor%ISOPEN THEN CLOSE mem_allocation_cursor; END IF;
    RAISE;
END;
