! Type names as procedure designators (DI extension E3): two initializers
! that match the interface, structure constructors that are not admissible
! (a private component without default initialization, a private component
! given a value, a pointer component, too many dummy arguments, a mismatch
! of a component's type or of the result, a subroutine interface), a type
! name associated with a data dummy or with a generic interface, a generic
! type without type arguments, an inaccessible type, a generic dummy whose interface matches
! nothing, and a type name as an initial procedure target.
module continue_compilation_traits_type_designator_m
    implicit none
    private
    public :: ILogger, Logger, Two, Secret, Given, Linked, Plain, Box, mk_two, &
        mk_secret, mk_given, mk_linked, mk_plain, mk_plain3, mk_int, mk_sub, &
        ctor1, use_two, use_secret, use_given, use_linked, use_plain, &
        use_plain3, use_int, use_sub, take_int, gen, build1

    abstract interface :: ILogger
        integer function level(self)
            type(itself), intent(in), pass :: self
        end function level
    end interface ILogger

    type, implements(ILogger) :: Logger
        integer :: lv = 1
    contains
        procedure :: level => logger_level
    end type Logger

    type :: Two
        integer :: v = 0
    contains
        initial :: two_a, two_b
    end type Two

    type :: Secret
        private
        integer :: n
    contains
        initial :: secret_init
    end type Secret

    type :: Given
        private
        integer :: n = 0
    end type Given

    type :: Linked
        integer, pointer :: p => null()
    end type Linked

    type :: Plain
        integer :: v = 1
    end type Plain

    type :: Hidden
        integer :: v = 1
    end type Hidden

    type :: Box{T}
        type(T) :: v
    end type Box

    interface gen
        module procedure gen_two
    end interface gen

    abstract interface
        function mk_two(x) result(r)
            import :: Two
            integer, intent(in) :: x
            type(Two) :: r
        end function mk_two

        function mk_secret() result(r)
            import :: Secret
            type(Secret) :: r
        end function mk_secret

        function mk_given(n) result(r)
            import :: Given
            integer, intent(in) :: n
            type(Given) :: r
        end function mk_given

        function mk_linked(p) result(r)
            import :: Linked
            integer, pointer, intent(in) :: p
            type(Linked) :: r
        end function mk_linked

        function mk_plain(x) result(r)
            import :: Plain
            real, intent(in) :: x
            type(Plain) :: r
        end function mk_plain

        function mk_plain3(a, b, c) result(r)
            import :: Plain
            integer, intent(in) :: a, b, c
            type(Plain) :: r
        end function mk_plain3

        function mk_int() result(r)
            integer :: r
        end function mk_int

        subroutine mk_sub()
        end subroutine mk_sub

        function ctor1{Trait :: T1, U}(a) result(res)
            class(T1), intent(in) :: a
            type(U) :: res
        end function ctor1
    end interface

contains

    integer function logger_level(self)
        class(Logger), intent(in) :: self
        logger_level = self%lv
    end function logger_level

    function two_a(x) result(r)
        integer, intent(in) :: x
        type(Two) :: r
        r%v = x
    end function two_a

    function two_b(y) result(r)
        integer, intent(in) :: y
        type(Two) :: r
        r%v = -y
    end function two_b

    function secret_init(n) result(r)
        integer, intent(in) :: n
        type(Secret) :: r
        r%n = n
    end function secret_init

    subroutine use_two(f)
        procedure(mk_two) :: f
    end subroutine use_two

    subroutine use_secret(f)
        procedure(mk_secret) :: f
    end subroutine use_secret

    subroutine use_given(f)
        procedure(mk_given) :: f
    end subroutine use_given

    subroutine use_linked(f)
        procedure(mk_linked) :: f
    end subroutine use_linked

    subroutine use_plain(f)
        procedure(mk_plain) :: f
    end subroutine use_plain

    subroutine use_plain3(f)
        procedure(mk_plain3) :: f
    end subroutine use_plain3

    subroutine use_int(f)
        procedure(mk_int) :: f
    end subroutine use_int

    subroutine use_sub(f)
        procedure(mk_sub) :: f
    end subroutine use_sub

    subroutine take_int(x)
        integer, intent(in) :: x
    end subroutine take_int

    subroutine gen_two(f)
        procedure(mk_two) :: f
    end subroutine gen_two

    function build1{Trait :: T1, U}(ctor, a) result(r)
        procedure(ctor1{T1,U}) :: ctor
        class(T1), intent(in) :: a
        type(U) :: r
        r = ctor(a)
    end function build1

end module continue_compilation_traits_type_designator_m

program continue_compilation_traits_type_designator
    use continue_compilation_traits_type_designator_m
    implicit none
    procedure(mk_plain), pointer :: q
    procedure(mk_int), pointer :: q2
    procedure(mk_two), pointer :: q3 => Two
    type(Logger) :: lg
    type(Plain) :: pl

    ! Two initializers match the interface.
    call use_two(Two)
    ! Secret's initializer takes an argument, and Secret() omits the
    ! private component n, which has no default.
    call use_secret(Secret)
    ! Given(n) gives a value to the private component n.
    call use_given(Given)
    ! A pointer component cannot be given by the designated procedure.
    call use_linked(Linked)
    ! The component is integer, the interface's dummy real.
    call use_plain(Plain)
    ! Three dummy arguments for a type with one component.
    call use_plain3(Plain)
    ! The result is not of the type.
    call use_int(Plain)
    ! A structure constructor is a function.
    call use_sub(Plain)
    ! A data dummy.
    call take_int(Plain)
    ! A generic interface.
    call gen(Two)
    ! A generic type without type arguments.
    call use_plain(Box)
    ! A private type is not accessible.
    call use_plain(Hidden)
    ! Procedure-pointer targets.
    q => Plain
    q2 => Plain
    ! Nothing of Plain matches ctor1{T1,U} with a trait object argument.
    pl = build1(Plain, lg)
end program continue_compilation_traits_type_designator
