! Overloaded generic messages of several traits (DI extension E6). Messages
! of one name of the traits that a type adopts, that constrain one generic
! parameter or that a trait extends are one requirement when their
! signatures correspond, whatever the order of their declarations; the
! others are further overloads. So a trait may declare a subset of the
! overloads of another, or add an overload to an inherited message. A type
! implements overloaded messages, also functions, with the specifics of its
! generic binding of their name, in any order, also when the binding
! extends its parent's. A call of a type's generic binding is resolved by
! the reference also when one of its specifics implements a message.
! GFortran does not accept this LFortran extension.
module traits_generic_overload_03_m
    implicit none
    private
    public :: IA, IB, IOne, IBoth, IGet, IAdd, IClient, Client, Box, Base, Child, &
        Getter, Adder, make_client, make_c1, setup_ab, setup_b, setup_one, &
        setup_both, use_get, use_add

    abstract interface
        function ctor0{U}() result(res)
            type(U) :: res
        end function ctor0
        function ctor1{Trait :: T1, U}(a) result(res)
            class(T1), intent(in) :: a
            type(U)               :: res
        end function ctor1
    end interface

    ! The two overloads in one order ...
    abstract interface :: IA
        subroutine register{Trait :: P, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor0{U})               :: ctor
        end subroutine register
        subroutine register{Trait :: P, Trait :: T1, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor1{T1,U})            :: ctor
        end subroutine register
    end interface

    ! ... and in the other, with other parameter names.
    abstract interface :: IB
        subroutine register{Trait :: Q, Trait :: S, Q :: V}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor1{S,V})             :: ctor
        end subroutine register
        subroutine register{Trait :: Q, Q :: V}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor0{V})               :: ctor
        end subroutine register
    end interface

    ! One of them.
    abstract interface :: IOne
        subroutine register{Trait :: P, Trait :: T1, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor1{T1,U})            :: ctor
        end subroutine register
    end interface

    ! An overload of an inherited message.
    abstract interface, extends(IOne) :: IBoth
        subroutine register{Trait :: P, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor0{U})               :: ctor
        end subroutine register
    end interface

    ! Overloaded functions.
    abstract interface :: IGet
        integer function get{Trait :: P}(self)
            type(itself), pass, intent(in) :: self
        end function get
        integer function get{Trait :: P}(self, n)
            type(itself), pass, intent(in) :: self
            integer, intent(in)            :: n
        end function get
    end interface

    ! A message that is not overloaded.
    abstract interface :: IAdd
        subroutine add{Trait :: P, P :: U}(self, ctor)
            type(itself), pass, intent(inout) :: self
            procedure(ctor0{U})               :: ctor
        end subroutine add
    end interface

    abstract interface :: IClient
        integer function serve(self)
            type(itself), intent(in), pass :: self
        end function serve
    end interface IClient

    type, implements(IClient) :: Client
        integer :: id = 0
    contains
        procedure :: serve => client_serve
    end type Client

    ! The specifics in another order than in IA.
    type, sealed, implements(IA + IB + IOne) :: Box
        integer :: n0 = 0, n1 = 0
    contains
        generic   :: register => box1, box0
        procedure :: box0, box1
    end type Box

    ! A generic binding that the extension extends with a specific of its own.
    type :: Base
        integer :: n0 = 0, n1 = 0, nint = 0
    contains
        generic   :: register => base0, base1
        procedure :: base0, base1
    end type Base

    type, extends(Base), implements(IBoth) :: Child
    contains
        generic   :: register => child_int
        procedure :: child_int
    end type Child

    type, sealed, implements(IGet) :: Getter
        integer :: v = 3
    contains
        generic   :: get => get0, get1
        procedure :: get0, get1
    end type Getter

    ! The message add is implemented by the generic specific of a generic
    ! binding that also has a specific of its own.
    type, sealed, implements(IAdd) :: Adder
        integer :: n = 0
    contains
        generic   :: add => add0, add_int
        procedure :: add0, add_int
    end type Adder

contains

    integer function client_serve(self)
        class(Client), intent(in) :: self
        client_serve = self%id
    end function client_serve

    function make_client() result(res)
        type(Client) :: res
        res%id = 7
    end function make_client

    function make_c1(a) result(res)
        class(IClient), intent(in) :: a
        type(Client) :: res
        res%id = a%serve()
    end function make_c1

    subroutine box0{Trait :: P, P :: U}(self, ctor)
        type(Box), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
        self%n0 = self%n0 + 1
    end subroutine box0

    subroutine box1{Trait :: P, Trait :: T1, P :: U}(self, ctor)
        type(Box), intent(inout) :: self
        procedure(ctor1{T1,U}) :: ctor
        self%n1 = self%n1 + 1
    end subroutine box1

    subroutine base0{Trait :: P, P :: U}(self, ctor)
        class(Base), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
        self%n0 = self%n0 + 1
    end subroutine base0

    subroutine base1{Trait :: P, Trait :: T1, P :: U}(self, ctor)
        class(Base), intent(inout) :: self
        procedure(ctor1{T1,U}) :: ctor
        self%n1 = self%n1 + 1
    end subroutine base1

    subroutine child_int(self, n)
        class(Child), intent(inout) :: self
        integer, intent(in) :: n
        self%nint = self%nint + n
    end subroutine child_int

    integer function get0{Trait :: P}(self)
        type(Getter), intent(in) :: self
        get0 = self%v
    end function get0

    integer function get1{Trait :: P}(self, n)
        type(Getter), intent(in) :: self
        integer, intent(in) :: n
        get1 = self%v * n
    end function get1

    subroutine add0{Trait :: P, P :: U}(self, ctor)
        type(Adder), intent(inout) :: self
        procedure(ctor0{U}) :: ctor
        self%n = self%n + 1
    end subroutine add0

    subroutine add_int(self, n)
        type(Adder), intent(inout) :: self
        integer, intent(in) :: n
        self%n = self%n + 100 * n
    end subroutine add_int

    ! Constrained by two traits that declare the overloads in other orders.
    subroutine setup_ab{IA + IB :: CT}(cont)
        type(CT), intent(inout) :: cont
        call cont%register{IClient}(make_client)
        call cont%register{IClient}(make_c1)
    end subroutine setup_ab

    subroutine setup_b{IB :: CT}(cont)
        type(CT), intent(inout) :: cont
        call cont%register{IClient}(make_client)
        call cont%register{IClient}(make_c1)
    end subroutine setup_b

    subroutine setup_one{IOne :: CT}(cont)
        type(CT), intent(inout) :: cont
        call cont%register{IClient}(make_c1)
    end subroutine setup_one

    subroutine setup_both{IBoth :: CT}(cont)
        type(CT), intent(inout) :: cont
        call cont%register{IClient}(make_client)
        call cont%register{IClient}(make_c1)
    end subroutine setup_both

    integer function use_get{IGet :: G}(x) result(r)
        type(G), intent(in) :: x
        r = x%get{IClient}() + x%get{IClient}(10)
    end function use_get

    subroutine use_add{IAdd :: A}(x)
        type(A), intent(inout) :: x
        call x%add{IClient}(make_client)
    end subroutine use_add

end module traits_generic_overload_03_m

program traits_generic_overload_03
    use traits_generic_overload_03_m
    implicit none
    type(Box) :: box_
    type(Child) :: child_
    type(Getter) :: getter_
    type(Adder) :: adder_

    call box_%register{IClient}(make_client)
    call box_%register{IClient}(make_c1)
    if (box_%n0 /= 1 .or. box_%n1 /= 1) error stop 1
    call setup_ab(box_)
    if (box_%n0 /= 2 .or. box_%n1 /= 2) error stop 2
    call setup_b(box_)
    if (box_%n0 /= 3 .or. box_%n1 /= 3) error stop 3
    call setup_one(box_)
    if (box_%n0 /= 3 .or. box_%n1 /= 4) error stop 4

    call child_%register{IClient}(make_client)
    call child_%register(5)
    call setup_both(child_)
    if (child_%n0 /= 2 .or. child_%n1 /= 1 .or. child_%nint /= 5) error stop 5

    if (use_get(getter_) /= 33) error stop 6
    if (getter_%get{IClient}(2) /= 6) error stop 7

    ! add_int, not the specific that implements the message.
    call adder_%add(5)
    if (adder_%n /= 500) error stop 8
    call adder_%add{IClient}(make_client)
    call use_add(adder_)
    if (adder_%n /= 502) error stop 9
    print *, box_%n0, box_%n1, child_%n0, child_%n1, child_%nint, adder_%n
end program traits_generic_overload_03
