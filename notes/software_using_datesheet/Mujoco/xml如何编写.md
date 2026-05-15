```xml

<mujoco model="single_leg">
    <compiler angle="degree"/>
    <option gravity="0 0 -9.81"/>

    <worldbody>
        <light pos="0 0 1.5" dir="0 0 -1" diffuse="1 1 1"/>
        <geom type="plane" size="1 1 0.1" rgba="0.9 0.9 0.9 1"/>

        <body name="base" pos="0 0 0.5">
            <geom type="box" size="0.05 0.05 0.05" rgba="0.8 0.2 0.2 1"/>

            <body name="leg" pos="0 0 0">
                <joint name="hip_joint" type="hinge" axis="0 1 0" pos="0 0 0"/>
                
                <geom type="capsule" size="0.02" fromto="0 0 0 0 0 -0.3" rgba="0.2 0.8 0.2 1" mass="1.0"/>
                
                </body>
        </body>
    </worldbody>

    <actuator>
        <motor joint="hip_joint" name="hip_motor" ctrlrange="-10 10" ctrllimited="true"/>
    </actuator>
</mujoco>
```